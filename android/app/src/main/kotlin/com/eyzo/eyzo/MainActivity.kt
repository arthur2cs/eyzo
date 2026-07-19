package com.eyzo.eyzo

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Pont natif pour lire les URI content:// transmises par le clavier (commitContent)
 * lors de l'insertion d'un GIF dans un champ de texte (voir specs.md §4.3).
 * L'accès en lecture à l'URI est accordé temporairement par l'IME au moment de l'insertion.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "eyzo/content_uri"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "readContentUri") {
                val uriString = call.argument<String>("uri")
                if (uriString.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "URI manquante", null)
                    return@setMethodCallHandler
                }
                try {
                    val uri = Uri.parse(uriString)
                    val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    if (bytes != null) {
                        result.success(bytes)
                    } else {
                        result.error("READ_FAILED", "Impossible d'ouvrir l'URI", null)
                    }
                } catch (e: Exception) {
                    result.error("READ_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
