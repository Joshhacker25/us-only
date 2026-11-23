package com.onlyus.app

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.onlyus.app/widget",
        ).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val prefs = getSharedPreferences(
                    "only_us_widget",
                    Context.MODE_PRIVATE,
                )
                val editor = prefs.edit()
                (call.argument<Boolean>("showNickname"))
                    ?.let { editor.putBoolean("showNickname", it) }
                (call.argument<Boolean>("showDays"))
                    ?.let { editor.putBoolean("showDays", it) }
                (call.argument<Boolean>("showNote"))
                    ?.let { editor.putBoolean("showNote", it) }
                (call.argument<Boolean>("showLastHeart"))
                    ?.let { editor.putBoolean("showLastHeart", it) }
                (call.argument<Boolean>("privacyMode"))
                    ?.let { editor.putBoolean("privacyMode", it) }
                (call.argument<String>("nickname"))
                    ?.let { editor.putString("nickname", it) }
                (call.argument<String>("sweetNote"))
                    ?.let { editor.putString("sweetNote", it) }
                (call.argument<String>("anniversary"))
                    ?.let { editor.putString("anniversary", it) }
                (call.argument<String>("lastHeart"))
                    ?.let { editor.putString("lastHeart", it) }
                editor.apply()
                sendBroadcast(
                    Intent("com.onlyus.app.widget.ACTION_UPDATE_WIDGET"),
                )
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
