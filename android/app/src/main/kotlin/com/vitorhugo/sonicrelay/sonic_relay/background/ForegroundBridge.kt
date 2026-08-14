package com.vitorhugo.sonicrelay.sonic_relay.background

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Process-wide bridge that forwards foreground-service notification actions
 * (open / stop / reconnect) from [SonicRelayForegroundService] back to Dart over
 * an [EventChannel].
 *
 * Actions raised while no sink is attached are queued rather than dropped. The window is real:
 * the notification outlives any activity, and the service can emit while Dart is still starting
 * up, while the activity is being recreated, or between an engine restart and Dart's
 * re-subscription. Silently discarding those was indistinguishable from a dead button — the
 * user's press did nothing and left no trace anywhere.
 *
 * All state is confined to the main thread, which is also where the sink must be used.
 */
object ForegroundBridge {

    private const val TAG = "SonicRelayBridge"

    /** Enough to cover a burst of presses during a restart; oldest is dropped beyond it. */
    private const val MAX_PENDING = 16

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pending = ArrayDeque<String>()
    private var eventSink: EventChannel.EventSink? = null

    fun attach(sink: EventChannel.EventSink?) {
        onMainThread {
            eventSink = sink
            if (sink == null) return@onMainThread
            if (pending.isNotEmpty()) {
                Log.i(TAG, "sink attached; flushing ${pending.size} queued action(s)")
            }
            while (pending.isNotEmpty()) {
                sink.success(pending.removeFirst())
            }
        }
    }

    fun detach() {
        onMainThread { eventSink = null }
    }

    /** Emits an action string ("open" | "stop" | "reconnect") to Dart. */
    fun emit(action: String) {
        onMainThread {
            val sink = eventSink
            if (sink == null) {
                if (pending.size >= MAX_PENDING) pending.removeFirst()
                pending.addLast(action)
                Log.w(TAG, "no sink attached; queued '$action' (${pending.size} pending)")
                return@onMainThread
            }
            Log.i(TAG, "delivering '$action' to Dart")
            sink.success(action)
        }
    }

    private fun onMainThread(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post { block() }
    }
}
