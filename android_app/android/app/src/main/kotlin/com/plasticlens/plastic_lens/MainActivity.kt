package com.plasticlens.plastic_lens

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tells Dart whether google-services.json was built in. Without it,
        // Firebase.initializeApp() never completes on Android, so the app
        // must not call it and runs local-only instead.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "plasticlens/config")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasFirebaseConfig" -> {
                        val id = resources.getIdentifier("google_app_id", "string", packageName)
                        result.success(id != 0)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
