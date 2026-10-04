package com.dmda.dmoneymanager

import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * Quick Settings tile ("Add expense"). Tapping it collapses the shade and
 * opens the app with a "quick_action" extra; MainActivity forwards that to
 * Flutter over the dmoney/quickadd channel, which opens the add sheet
 * straight at the amount keypad.
 *
 * Only instantiated on API 24+, where the QS tile framework exists.
 */
@RequiresApi(Build.VERSION_CODES.N)
class QuickAddTileService : TileService() {
    override fun onClick() {
        super.onClick()
        val intent: Intent? =
            packageManager.getLaunchIntentForPackage(packageName)?.apply {
                putExtra("quick_action", "expense")
            }
        if (intent != null) {
            startActivityAndCollapse(intent)
        }
    }
}
