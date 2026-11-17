package com.staticradio.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class RadioLockscreenReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action ?: return
        when (action) {
            RadioLockscreenService.ACTION_PREV -> {
                MainActivity.sendLockscreenAction("onPrevChannel")
            }
            RadioLockscreenService.ACTION_NEXT -> {
                MainActivity.sendLockscreenAction("onNextChannel")
            }
            RadioLockscreenService.ACTION_TALK -> {
                MainActivity.sendLockscreenAction("onTalkToggle")
            }
        }
    }
}
