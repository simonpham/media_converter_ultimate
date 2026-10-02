package io.sofluffy.mcu

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var outputStorage: OutputStorage? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        outputStorage = OutputStorage(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.sofluffy.mcu/output_storage")
            .setMethodCallHandler(outputStorage)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (outputStorage?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDestroy() {
        outputStorage?.detach()
        super.onDestroy()
    }
}
