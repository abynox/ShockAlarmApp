import 'package:signalr_core/signalr_core.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../stores/alarm_store.dart';
import 'openshock.dart';

class _HttpClient extends http.BaseClient {
  final _httpClient = http.Client();
  final Map<String, String> headers;

  _HttpClient({required this.headers});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _httpClient.send(request);
  }
}

class OpenShockWS {
  Token t;

  HubConnection? connection = null;

  // Constructor
  OpenShockWS(this.t);

  // Start the connection
  Future startConnection() async {
    try {
      final httpClient = _HttpClient(headers: {
        'OpenShockSession': this.t.token,
        'User-Agent': GetUserAgent(),
      });
      String server = this.t.server.replaceAll("http", "ws");
      print(server);
      connection = HubConnectionBuilder()
          .withAutomaticReconnect()
          .withUrl(
              server + '/1/hubs/user',
              HttpConnectionOptions(
                  logging: (level, message) => print(message),
                  client: httpClient,
                  skipNegotiation: true,
                  transport: HttpTransportType.webSockets,
                  logMessageContent: true))
          .build();

      await connection!.start();
      print('Connection started');
    } catch (e) {
      print(e);
    }
  }

  // Stop the connection
  Future stopConnection() async {
    if (connection != null) {
      await connection!.stop();
      print('Connection stopped');
    } else {
      print('Connection is not established.');
    }
  }

    // Add a message handler for a specific event
  void addMessageHandler(String methodName, MethodInvocationFunc handler) {
    if (connection != null) {
      connection!.on(methodName, handler);
      print('Handler added for $methodName');
    } else {
      print('Connection not established yet.');
    }
  }

  // Remove a message handler for a specific event
  void removeMessageHandler(String methodName) {
    if (connection != null) {
      connection!.off(methodName);
      print('Handler removed for $methodName');
    } else {
      print('Connection not established yet.');
    }
  }

  Future<bool> sendControls(List<Control> controls, String customName, {int depth = 0}) async {
    if(depth > 3) {
      return false;
    }
    if(connection == null || connection!.state != HubConnectionState.connected) {
      await startConnection();
      return sendControls(controls, customName, depth: depth + 1);
    }
    try {
      // Wrap the Map in a List
      await connection!.invoke('ControlV2', args: [
        controls.map((e) => e.toJsonWS()).toList(),
        customName
      ]);
    } catch (e) {
      return false;
    }

    return true;
  }
}