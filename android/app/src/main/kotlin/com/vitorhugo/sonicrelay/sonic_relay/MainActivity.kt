package com.vitorhugo.sonicrelay.sonic_relay

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    // Attach to the process-lifetime engine pre-warmed in [SonicRelayApplication]
    // instead of letting the framework create one scoped to this activity. A
    // non-null cached engine id also makes the base class's
    // shouldDestroyEngineWithHost() return false, so destroying this activity
    // (e.g. the task being swiped away) no longer tears down the Dart isolate
    // and kills the active stream. See issue #22.
    override fun getCachedEngineId(): String = SonicRelayApplication.ENGINE_ID

    // The foreground-service channels are deliberately NOT registered here. They belong to the
    // process-lifetime engine and are registered in SonicRelayApplication before Dart starts —
    // registering them per activity attach is what left the notification buttons dead. See
    // ForegroundChannels for the full account.

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Asked for here rather than from the channel handler that starts the service: a
        // permission request needs a live activity, and the service is routinely started while
        // none is attached.
        ensureNotificationPermission()
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFICATIONS)
        }
    }

    companion object {
        private const val REQ_NOTIFICATIONS = 4210
    }
}
