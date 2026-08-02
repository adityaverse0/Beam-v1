package org.localsend.localsend_app

import android.annotation.SuppressLint
import android.app.ActivityManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * Premium Service used for Android Quick Settings Tile in Beam.
 */
@RequiresApi(Build.VERSION_CODES.N)
class QuickTileService : TileService() {

    companion object {
        const val ACTION_QUICK_BEAM = "org.localsend.localsend_app.ACTION_QUICK_BEAM"
        const val EXTRA_QUICK_BEAM = "quick_beam"

        @Volatile
        var currentState: String = "idle"
            private set

        fun updateTileState(context: Context, state: String) {
            if (currentState == state) return
            currentState = state
            try {
                requestListeningState(context, ComponentName(context, QuickTileService::class.java))
            } catch (e: Exception) {
                Log.w("QuickTileService", "Failed to request tile update: $e")
            }
        }
    }

    override fun onClick() {
        super.onClick()
        launchApp()
    }

    override fun onStartListening() {
        super.onStartListening()
        setupTileState()
    }

    private fun setupTileState() {
        val tile = qsTile ?: return

        tile.label = "Beam"
        tile.icon = Icon.createWithResource(this, R.mipmap.ic_launcher_quicktile_foreground)

        when (currentState) {
            "searching" -> {
                tile.state = Tile.STATE_ACTIVE
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    tile.subtitle = "Searching..."
                }
            }
            "connected" -> {
                tile.state = Tile.STATE_ACTIVE
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    tile.subtitle = "Connected"
                }
            }
            "transferring" -> {
                tile.state = Tile.STATE_ACTIVE
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    tile.subtitle = "Transferring..."
                }
            }
            else -> { // "idle"
                tile.state = Tile.STATE_INACTIVE
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    tile.subtitle = "Tap to scan"
                }
            }
        }

        tile.updateTile()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun launchApp() {
        try {
            val launchIntent = getLaunchIntent()
            launchIntent.action = ACTION_QUICK_BEAM
            launchIntent.putExtra(EXTRA_QUICK_BEAM, true)
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(
                        this,
                        0,
                        launchIntent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                )
            } else {
                startActivityAndCollapse(launchIntent)
            }
        } catch (e: Exception) {
            Log.w("QuickTileService", "Exception launching app: $e")
        }
    }

    private fun getLaunchIntent(): Intent {
        val cleanIntent = packageManager.getLaunchIntentForPackage(packageName)
        return cleanIntent ?: run {
            val dirtyIntent = MainActivity.createDefaultIntent(this)
            dirtyIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            dirtyIntent
        }
    }
}