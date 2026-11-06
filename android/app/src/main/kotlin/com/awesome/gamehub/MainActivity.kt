package com.awesome.gamehub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build

class MainActivity : FlutterActivity() {
    private var devices: GameDeviceBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        devices = GameDeviceBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ludivex/mobile_games")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listGames" -> {
                        // Android discovery runs automatically; importing remains a user choice.
                        Thread {
                            try {
                                val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                                @Suppress("DEPRECATION")
                                val apps = packageManager.queryIntentActivities(intent, 0)
                                    .filter { it.activityInfo.packageName != packageName }
                                    .distinctBy { it.activityInfo.packageName }
                                    .map {
                                        val info = it.activityInfo.applicationInfo
                                        @Suppress("DEPRECATION")
                                        val isGame = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                            info.category == ApplicationInfo.CATEGORY_GAME) ||
                                            (info.flags and ApplicationInfo.FLAG_IS_GAME) != 0
                                        mapOf<String, Any>("package" to it.activityInfo.packageName,
                                            "title" to it.loadLabel(packageManager).toString(), "isGame" to isGame)
                                    }.sortedWith(compareByDescending<Map<String, Any>> { it["isGame"] as Boolean }
                                        .thenBy { (it["title"] as String).lowercase() })
                                runOnUiThread { result.success(apps) }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("LIST_FAILED", "Não foi possível listar os aplicativos.", null) }
                            }
                        }.start()
                    }
                    "launchGame" -> {
                        val target = call.argument<String>("package")
                        if (target == null || !Regex("^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z][a-zA-Z0-9_]*)+$").matches(target)) {
                            result.error("INVALID_PACKAGE", "Pacote inválido.", null)
                        } else {
                            try {
                                val intent = packageManager.getLaunchIntentForPackage(target)
                                if (intent == null) {
                                    result.error("NOT_INSTALLED", "O jogo foi removido ou não pode ser aberto.", null)
                                } else {
                                    startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                    result.success(null)
                                }
                            } catch (error: Exception) {
                                result.error("LAUNCH_FAILED", "Não foi possível abrir o jogo.", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        devices?.onPermissionResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        devices?.close()
        super.onDestroy()
    }
}
