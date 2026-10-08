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
        // Ad unit IDs are build resources, filled from env.props by Gradle.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.sofluffy.mcu/ad_units")
            .setMethodCallHandler { call, result ->
                if (call.method != "getAdUnitIds") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(
                    mapOf(
                        "jobManager" to getString(R.string.admob_job_manager_ad_unit_id),
                        "filePicker" to getString(R.string.admob_file_picker_ad_unit_id),
                        "outputFormatPicker" to getString(R.string.admob_output_format_picker_ad_unit_id),
                        "previewPage" to getString(R.string.admob_preview_page_ad_unit_id),
                    ),
                )
            }
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
