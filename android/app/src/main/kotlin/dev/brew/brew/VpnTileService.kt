package dev.brew.brew

import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.graphics.drawable.Icon

class VpnTileService : TileService() {
    override fun onTileAdded() {
        super.onTileAdded()
        qsTile.state = Tile.STATE_INACTIVE
        qsTile.label = "brew VPN"
        qsTile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        // Toggle VPN connection
        // This would need integration with Flutter via MethodChannel
        qsTile.state = if (qsTile.state == Tile.STATE_ACTIVE) {
            Tile.STATE_INACTIVE
        } else {
            Tile.STATE_ACTIVE
        }
        qsTile.updateTile()
    }
}
