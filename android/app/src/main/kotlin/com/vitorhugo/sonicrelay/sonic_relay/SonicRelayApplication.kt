package com.vitorhugo.sonicrelay.sonic_relay

import android.app.Application
import com.vitorhugo.sonicrelay.sonic_relay.background.ForegroundChannels
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Pre-warms a single [FlutterEngine] at process startup and keeps it in
 * [FlutterEngineCache] for the lifetime of the process, rather than letting
 * [MainActivity] create (and, on destruction, tear down) its own engine.
 *
 * This is what lets an active viewer session — the WebRTC peer connection,
 * signaling socket, audio playback, and the Riverpod container that owns
 * them — survive `MainActivity` being destroyed (screen rotation aside, most
 * notably when the user swipes SonicRelay away from recent apps). The engine,
 * and everything the Dart isolate is holding onto, now lives and dies with
 * the process, not with the activity. See issue #22.
 */
class SonicRelayApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        val engine = FlutterEngine(this)
        // Everything the Dart entrypoint may talk to must be registered before it runs. The
        // foreground channels in particular: Dart subscribes to the notification-action event
        // channel on its own schedule, and a subscription that lands before the handler exists
        // is not retried — it just leaves the notification buttons permanently dead. Registering
        // them here (once per process, on the engine that outlives every activity) closes that
        // window; see ForegroundChannels.
        GeneratedPluginRegistrant.registerWith(engine)
        ForegroundChannels.register(this, engine.dartExecutor.binaryMessenger)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "sonicrelay_main_engine"
    }
}
