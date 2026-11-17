package com.staticradio.app

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.staticradio.app/lockscreen"
        var channel: MethodChannel? = null

        fun sendLockscreenAction(action: String) {
            channel?.invokeMethod(action, null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startLockscreenService" -> {
                    val ticker = call.argument<String>("ticker") ?: "SQUAD"
                    val freq = call.argument<String>("frequency") ?: "140.345 MHz"
                    val isTransmitting = call.argument<Boolean>("isTransmitting") ?: false
                    val isBusy = call.argument<Boolean>("isBusy") ?: false

                    val intent = Intent(this, RadioLockscreenService::class.java).apply {
                        putExtra(RadioLockscreenService.EXTRA_TICKER, ticker)
                        putExtra(RadioLockscreenService.EXTRA_FREQ, freq)
                        putExtra(RadioLockscreenService.EXTRA_IS_TRANSMITTING, isTransmitting)
                        putExtra(RadioLockscreenService.EXTRA_IS_BUSY, isBusy)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "updateLockscreenState" -> {
                    val ticker = call.argument<String>("ticker") ?: "SQUAD"
                    val freq = call.argument<String>("frequency") ?: "140.345 MHz"
                    val isTransmitting = call.argument<Boolean>("isTransmitting") ?: false
                    val isBusy = call.argument<Boolean>("isBusy") ?: false

                    RadioLockscreenService.instance?.updateState(
                        ticker, freq, isTransmitting, isBusy
                    )
                    result.success(true)
                }

                "stopLockscreenService" -> {
                    val intent = Intent(this, RadioLockscreenService::class.java)
                    stopService(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        channel = null
        super.onDestroy()
    }
}
