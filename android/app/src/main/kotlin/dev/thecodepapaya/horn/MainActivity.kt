package dev.thecodepapaya.horn

import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.thecodepapaya.horn/toast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showToast" -> {
                        val message = call.argument<String>("msg")
                        if (message == null) {
                            result.error("bad_args", "msg is required", null)
                        } else {
                            Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
