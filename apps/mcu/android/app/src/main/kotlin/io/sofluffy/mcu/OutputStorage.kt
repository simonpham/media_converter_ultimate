package io.sofluffy.mcu

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

/** Streams exports outside the UI thread. Receipts survive a process restart until Dart commits the job. */
internal class OutputStorage(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val context = activity.applicationContext
    private val resolver = context.contentResolver
    private val receipts = context.getSharedPreferences("output_export_receipts", 0)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var picker: MethodChannel.Result? = null
    private val requestCode = 7104
    private val downloadPath = "${Environment.DIRECTORY_DOWNLOADS}/MediaConverterPro/"

    private class StorageError(val code: String, message: String) : Exception(message)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "capabilities") {
            result.success(mapOf("downloads" to (Build.VERSION.SDK_INT >= 29)))
            return
        }
        if (call.method == "pickTree") {
            pickTree(call.argument("initialUri"), result)
            return
        }
        if (call.method == "share" || call.method == "open") {
            try {
                val uri = Uri.parse(call.argument<String>("uri")!!)
                val intent = Intent(if (call.method == "share") Intent.ACTION_SEND else Intent.ACTION_VIEW).apply {
                    val mime = resolver.getType(uri) ?: "application/octet-stream"
                    if (call.method == "share") {
                        type = mime
                        putExtra(Intent.EXTRA_STREAM, uri)
                    } else {
                        setDataAndType(uri, mime)
                    }
                    clipData = ClipData.newUri(resolver, "", uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                activity.startActivity(if (call.method == "share") Intent.createChooser(intent, null) else intent)
                result.success(null)
            } catch (error: Exception) {
                result.error("action_failed", error.message, null)
            }
            return
        }
        worker.execute {
            try {
                val value: Any? = when (call.method) {
                    "export" -> export(call)
                    "recover" -> {
                        val receipt = receipts.getString(call.argument<String>("id")!!, null)?.let { JSONObject(it) }
                        if (receipt != null && receipt.optBoolean("ready")) {
                            val uri = Uri.parse(receipt.getString("uri"))
                            if (exists(uri)) {
                                if (receipt.getString("destination") == "downloads" && Build.VERSION.SDK_INT >= 29) publish(uri)
                                mapOf("uri" to uri.toString(), "name" to displayName(uri))
                            } else null
                        } else null
                    }
                    "acknowledge" -> {
                        check(receipts.edit().remove(call.argument<String>("id")!!).commit())
                        null
                    }
                    "exists" -> exists(Uri.parse(call.argument<String>("uri")!!))
                    "contains" -> find(call.argument<String>("destination")!!, call.argument<String>("name")!!) != null
                    "validateTree" -> {
                        validateTree(Uri.parse(call.argument<String>("uri")!!))
                        null
                    }
                    "delete" -> {
                        val uri = Uri.parse(call.argument<String>("uri")!!)
                        val deleted = if (DocumentsContract.isDocumentUri(context, uri)) {
                            DocumentsContract.deleteDocument(resolver, uri)
                        } else {
                            resolver.delete(uri, null, null) > 0
                        }
                        if (!deleted && exists(uri)) throw StorageError("delete_failed", "Could not delete output")
                        null
                    }
                    else -> throw StorageError("unsupported", "Unknown output operation")
                }
                main.post { result.success(value) }
            } catch (error: Exception) {
                val code = when (error) {
                    is StorageError -> error.code
                    is SecurityException -> "access_expired"
                    else -> "export_failed"
                }
                main.post { result.error(code, error.message, null) }
            }
        }
    }

    private fun pickTree(initialUri: String?, result: MethodChannel.Result) {
        if (picker != null) {
            result.error("picker_busy", "Folder picker is already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= 26 && initialUri != null) {
                val tree = Uri.parse(initialUri)
                putExtra(DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree)))
            }
        }
        try {
            // Launch directly: package-visibility queries can report a false negative.
            picker = result
            activity.startActivityForResult(intent, requestCode)
        } catch (error: ActivityNotFoundException) {
            picker = null
            result.error("picker_unavailable", "System folder picker is unavailable", null)
        } catch (error: Exception) {
            picker = null
            result.error("picker_failed", error.message, null)
        }
    }

    fun onActivityResult(code: Int, status: Int, data: Intent?): Boolean {
        if (code != requestCode) return false
        val result = picker ?: return true
        picker = null
        val tree = data?.data
        if (status != Activity.RESULT_OK || tree == null) {
            result.success(null) // Cancellation is not a failure.
            return true
        }
        worker.execute {
            try {
                val flags = data!!.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                if (flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION == 0) {
                    throw StorageError("not_writable", "Selected folder has no write access")
                }
                resolver.takePersistableUriPermission(tree, flags)
                validateTree(tree)
                cleanAbandonedExports()
                val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                val label = displayName(root)
                main.post { result.success(mapOf("uri" to tree.toString(), "label" to label)) }
            } catch (error: Exception) {
                main.post { result.error("not_writable", error.message, null) }
            }
        }
        return true
    }

    fun detach() {
        picker?.error("picker_failed", "Folder picker was interrupted", null)
        picker = null
        worker.shutdown() // Already queued exports finish with the application context.
    }

    private fun validateTree(tree: Uri) {
        val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        resolver.query(root, arrayOf(DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_FLAGS), null, null, null)?.use {
            if (!it.moveToFirst() || it.getString(0) != DocumentsContract.Document.MIME_TYPE_DIR ||
                it.getInt(1) and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE == 0) {
                throw StorageError("not_writable", "Folder does not support creating files")
            }
        } ?: throw StorageError("access_expired", "Folder access is unavailable")
        if (resolver.persistedUriPermissions.none { it.uri == tree && it.isWritePermission }) {
            throw StorageError("access_expired", "Folder access must be granted again")
        }
    }

    private fun exists(uri: Uri): Boolean = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
        it.moveToFirst()
    } ?: false

    private fun displayName(uri: Uri): String = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
        if (it.moveToFirst()) it.getString(0) else null
    } ?: throw StorageError("export_failed", "Output name is unavailable")

    private fun find(destination: String, name: String): Uri? {
        if (destination == "downloads") {
            if (Build.VERSION.SDK_INT < 29) throw StorageError("unsupported", "Downloads requires Android 10")
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            resolver.query(collection, arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} = ? AND ${MediaStore.MediaColumns.IS_PENDING} = 0",
                arrayOf(downloadPath, name), null)?.use {
                if (it.moveToFirst()) return ContentUris.withAppendedId(collection, it.getLong(0))
            }
        } else {
            val tree = Uri.parse(destination)
            validateTree(tree)
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            resolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
                while (it.moveToNext()) {
                    if (it.getString(1) == name) return DocumentsContract.buildDocumentUriUsingTree(tree, it.getString(0))
                }
            } ?: throw StorageError("access_expired", "Could not read selected folder")
        }
        return null
    }

    private fun saveReceipt(id: String, receipt: JSONObject) {
        if (!receipts.edit().putString(id, receipt.toString()).commit()) {
            throw StorageError("export_failed", "Could not save export recovery state")
        }
    }

    private fun export(call: MethodCall): Map<String, String> {
        val id = call.argument<String>("id")!!
        val destination = call.argument<String>("destination")!!
        val name = call.argument<String>("name")!!
        require(name.isNotBlank() && !name.contains('/') && !name.contains('\\') && name != "." && name != "..")
        val source = File(call.argument<String>("source")!!).canonicalFile
        val appRoot = File(context.applicationInfo.dataDir).canonicalFile.path + File.separator
        require(source.path.startsWith(appRoot) && source.isFile) { "Export source must be an app-owned file" }
        cleanAbandonedExports()
        val previous = receipts.getString(id, null)?.let { JSONObject(it) }
        if (previous != null) {
            val uri = Uri.parse(previous.getString("uri"))
            val same = previous.getString("destination") == destination && previous.getString("requestedName") == name
            if (previous.optBoolean("ready")) {
                if (same && exists(uri)) {
                    if (destination == "downloads" && Build.VERSION.SDK_INT >= 29) publish(uri)
                    return mapOf("uri" to uri.toString(), "name" to displayName(uri))
                }
                // An explicit destination/name change preserves any already finished output.
            } else {
                // Only the exact incomplete URI created by this transaction can be removed.
                try {
                    removeIncomplete(uri, previous.getString("destination"))
                } catch (error: Exception) {
                    if (same) throw error
                    // A revoked old grant must not prevent an explicit fallback export.
                    // Keep ownership evidence for cleanup if access is granted again.
                    saveReceipt("abandoned:$id:${java.util.UUID.randomUUID()}", previous)
                }
            }
            check(receipts.edit().remove(id).commit())
        }
        if (find(destination, name) != null) throw StorageError("already_exists", name)
        val mime = call.argument<String>("mime") ?: MimeTypeMap.getSingleton()
            .getMimeTypeFromExtension(name.substringAfterLast('.', "").lowercase()) ?: "application/octet-stream"
        val uri = if (destination == "downloads") {
            if (Build.VERSION.SDK_INT < 29) throw StorageError("unsupported", "Downloads requires Android 10")
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, downloadPath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            resolver.insert(MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values)
        } else {
            val tree = Uri.parse(destination)
            val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            DocumentsContract.createDocument(resolver, root, mime, name)
        } ?: throw StorageError("export_failed", "Could not create output")
        val receipt = JSONObject().put("uri", uri.toString()).put("destination", destination)
            .put("requestedName", name).put("ready", false)
        var ready = false
        try {
            saveReceipt(id, receipt)
            resolver.openOutputStream(uri, "w")?.use { output ->
                source.inputStream().use { input -> input.copyTo(output) }
                output.flush()
            } ?: throw StorageError("export_failed", "Could not open output")
            saveReceipt(id, receipt.put("ready", true))
            ready = true
            if (destination == "downloads" && Build.VERSION.SDK_INT >= 29) publish(uri)
            return mapOf("uri" to uri.toString(), "name" to displayName(uri))
        } catch (error: Exception) {
            if (!ready) {
                try {
                    removeIncomplete(uri, destination)
                    receipts.edit().remove(id).commit()
                } catch (cleanup: Exception) {
                    error.addSuppressed(cleanup) // Keep the receipt so a retry can clean it safely.
                }
            }
            throw error
        }
    }

    private fun cleanAbandonedExports() {
        for ((key, value) in receipts.all) {
            if (!key.startsWith("abandoned:") || value !is String) continue
            try {
                val receipt = JSONObject(value)
                if (!receipt.optBoolean("ready")) {
                    removeIncomplete(Uri.parse(receipt.getString("uri")), receipt.getString("destination"))
                    receipts.edit().remove(key).commit()
                }
            } catch (_: Exception) {
                // The original provider can remain unavailable; retain the exact URI.
            }
        }
    }

    private fun removeIncomplete(uri: Uri, destination: String) {
        if (destination == "downloads") {
            if (resolver.delete(uri, null, null) == 0 && exists(uri)) {
                throw StorageError("export_failed", "Could not remove incomplete output")
            }
        }
        else if (exists(uri) && !DocumentsContract.deleteDocument(resolver, uri)) {
            throw StorageError("export_failed", "Could not remove incomplete output")
        }
    }

    private fun publish(uri: Uri) {
        if (resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null) != 1) {
            throw StorageError("export_failed", "Could not publish output")
        }
    }
}
