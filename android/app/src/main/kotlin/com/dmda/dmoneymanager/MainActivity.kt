package com.dmda.dmoneymanager

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // Channel for launcher shortcuts + the Quick Settings tile. Both fire
    // intents carrying a "quick_action" extra ("expense" | "income");
    // MainActivity forwards it to Flutter, which opens the add sheet.
    private var quickAddChannel: MethodChannel? = null
    private var pendingQuickAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        quickAddChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dmoney/quickadd")
        quickAddChannel?.setMethodCallHandler { call, result ->
            if (call.method == "takePendingAction") {
                result.success(pendingQuickAction)
                pendingQuickAction = null
            } else {
                result.notImplemented()
            }
        }
        // Cold start via shortcut / tile: the intent is already here.
        handleQuickActionIntent(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dmoney/update")
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("ARG", "Missing APK path", null)
                        return@setMethodCallHandler
                    }
                    // Android 8+: installing from the app requires the user to
                    // allow "unknown sources" for this package first. Send
                    // them to the system toggle; the Dart side explains it.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.error("UNKNOWN_SOURCES", "Unknown sources not allowed", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            File(path)
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INSTALL", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Warm start: the app is already running.
        handleQuickActionIntent(intent)
    }

    private fun handleQuickActionIntent(intent: Intent?) {
        val action = intent?.getStringExtra("quick_action") ?: return
        if (action != "expense" && action != "income") return
        val channel = quickAddChannel
        if (channel != null) {
            channel.invokeMethod("onQuickAction", action)
        } else {
            // Flutter isn't up yet (cold start raced the engine init);
            // the Dart side picks it up via takePendingAction.
            pendingQuickAction = action
        }
    }
}
