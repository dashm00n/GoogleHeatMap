package de.vierzigmann.google_heat_map

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Nimmt per "Teilen" oder "Öffnen mit" übergebene JSON-Dateien entgegen,
 * kopiert sie in den App-Cache und reicht den Pfad an Flutter weiter.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingFile" -> {
                        result.success(pendingPath)
                        pendingPath = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val uri: Uri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            else -> null
        } ?: return
        // Nicht erneut importieren, falls die Activity neu aufgebaut wird.
        intent.action = null

        Thread {
            val path = try {
                val target = File(cacheDir, "shared_timeline.json")
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { input.copyTo(it) }
                }
                target.path
            } catch (e: Exception) {
                null
            }
            runOnUiThread {
                if (path != null) {
                    pendingPath = path
                    channel?.invokeMethod("fileAvailable", null)
                }
            }
        }.start()
    }

    companion object {
        private const val CHANNEL = "de.vierzigmann.google_heat_map/import"
    }
}
