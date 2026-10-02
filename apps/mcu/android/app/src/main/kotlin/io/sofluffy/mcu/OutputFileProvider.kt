package io.sofluffy.mcu

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.security.MessageDigest
import java.util.Locale

/** Grants read access only to individually registered output files, without a cache copy. */
class OutputFileProvider : ContentProvider() {
    companion object {
        private fun records(context: Context) = context.getSharedPreferences("output_file_uris", 0)

        fun uriForFile(context: Context, location: String): Uri {
            val file = File(location).canonicalFile
            if (!file.isFile || !file.canRead()) throw FileNotFoundException("Output is unavailable")
            val id = MessageDigest.getInstance("SHA-256")
                .digest(file.path.toByteArray(Charsets.UTF_8))
                .joinToString("") { "%02x".format(it) }
            val preferences = records(context)
            if (preferences.getString(id, null) != file.path &&
                !preferences.edit().putString(id, file.path).commit()) {
                throw IOException("Could not register output access")
            }
            return Uri.Builder().scheme("content")
                .authority("${context.packageName}.output_files")
                .appendPath(id).appendPath(file.name).build()
        }
    }

    override fun onCreate() = true

    private fun fileFor(uri: Uri): File {
        val segments = uri.pathSegments
        if (segments.size != 2) throw FileNotFoundException("Unknown output")
        val preferences = records(requireNotNull(context))
        val path = preferences.getString(segments[0], null)
            ?: throw FileNotFoundException("Unknown output")
        val file = File(path)
        if (file.name != segments[1]) throw FileNotFoundException("Unknown output")
        if (!file.isFile || !file.canRead()) {
            preferences.edit().remove(segments[0]).apply()
            throw FileNotFoundException("Output is unavailable")
        }
        return file
    }

    override fun getType(uri: Uri): String? {
        val file = try { fileFor(uri) } catch (_: FileNotFoundException) { return null }
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase(Locale.ROOT))
            ?: "application/octet-stream"
    }

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?
    ): Cursor {
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val file = try { fileFor(uri) } catch (_: FileNotFoundException) { return MatrixCursor(columns) }
        return MatrixCursor(columns).apply {
            addRow(columns.map { column ->
                when (column) {
                    OpenableColumns.DISPLAY_NAME -> file.name
                    OpenableColumns.SIZE -> file.length()
                    else -> null
                }
            })
        }
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("Output access is read-only")
        return ParcelFileDescriptor.open(fileFor(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri =
        throw UnsupportedOperationException("Output access is read-only")

    override fun update(
        uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?
    ): Int = throw UnsupportedOperationException("Output access is read-only")

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException("Output access is read-only")
}
