package de.computerelite.shockalarm

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val REQUEST_CODE = 101

    private var resultCallback: MethodChannel.Result? = null
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
        MethodChannel(flutterEngine!!.dartExecutor!!.binaryMessenger, "shock-alarm/permissions").setMethodCallHandler {
            call, result ->
            if (call.method == "requestScheduleExactAlarmPermission") {
                resultCallback = result
                requestScheduleExactAlarmPermission()
            } else {
                result.notImplemented()
            }
        }
    }


    private fun requestScheduleExactAlarmPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SCHEDULE_EXACT_ALARM) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SCHEDULE_EXACT_ALARM), REQUEST_CODE)
        } else {
            resultCallback?.success(true)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        if (requestCode == REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            resultCallback?.success(granted)
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
