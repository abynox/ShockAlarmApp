package de.computerelite.shockalarm

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.action == Intent.ACTION_VIEW) {
            flutterEngine?.dartExecutor?.let {
                MethodChannel(
                    it,
                    "shock-alarm/protocol"
                ).invokeMethod("onProtocolUrlReceived", intent.data?.toString())
            }
        }
    }
}
