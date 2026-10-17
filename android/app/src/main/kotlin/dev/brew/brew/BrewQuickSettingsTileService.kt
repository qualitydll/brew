package dev.brew.brew

import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import java.util.UUID

/**
 * Quick Settings tile for starting/stopping the last configured Brew VPN.
 * Android asks for VPN consent in an Activity, so first-time users are sent
 * to Brew; after consent and one successful connection the tile can toggle
 * the saved Mihomo configuration directly.
 */
class BrewQuickSettingsTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        syncTile()
    }

    override fun onClick() {
        super.onClick()
        val prefs = getSharedPreferences(MihomoVpnService.TILE_PREFS, MODE_PRIVATE)
        if (VpnService.prepare(this) != null) {
            openBrew()
            return
        }

        val activeSessionId = prefs.getString(MihomoVpnService.PREF_ACTIVE_SESSION_ID, null)
        val intent = Intent(this, MihomoVpnService::class.java)
        if (!activeSessionId.isNullOrBlank()) {
            intent.action = MihomoVpnService.ACTION_STOP
            intent.putExtra(MihomoVpnService.EXTRA_SESSION_ID, activeSessionId)
        } else {
            val configPath = prefs.getString(MihomoVpnService.PREF_CONFIG_PATH, null)
            if (configPath.isNullOrBlank()) {
                openBrew()
                return
            }
            intent.action = MihomoVpnService.ACTION_START
            intent.putExtra(MihomoVpnService.EXTRA_CONFIG_PATH, configPath)
            intent.putExtra(MihomoVpnService.EXTRA_SESSION_ID, UUID.randomUUID().toString())
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            qsTile?.state = if (activeSessionId.isNullOrBlank()) {
                Tile.STATE_ACTIVE
            } else {
                Tile.STATE_INACTIVE
            }
            qsTile?.label = "Brew VPN"
            qsTile?.updateTile()
        } catch (_: Exception) {
            openBrew()
        }
    }

    private fun syncTile() {
        val prefs = getSharedPreferences(MihomoVpnService.TILE_PREFS, MODE_PRIVATE)
        val active = !prefs.getString(MihomoVpnService.PREF_ACTIVE_SESSION_ID, null).isNullOrBlank()
        qsTile?.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        qsTile?.label = "Brew VPN"
        qsTile?.updateTile()
    }

    private fun openBrew() {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivityAndCollapse(intent)
    }
}
