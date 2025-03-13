import 'package:http/http.dart' as http;

class FirmwareGetter {
  static Future<Map<String, String>> getAvailableFirmware() async {
    String baseUrl = "https://firmware.openshock.org/";
    List<String> branches = ["develop", "stable", "beta"];

    Map<String, String> firmware = {};
    for(String branch in branches) {
      var response = await http.get(Uri.parse("${baseUrl}version-$branch.txt"));
      if (response.statusCode == 200) {
        firmware[branch] = response.body.trim();
      } else {
        throw Exception('Failed to load firmware');
      }
    }
    return firmware;
  }
}