package com.multipushed

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Context.ALARM_SERVICE
import android.content.Intent
import android.os.Build
import android.os.Build.VERSION.SDK_INT
import android.util.Log

class WatchdogReceiver : BroadcastReceiver() {
    private val QUEUE_REQUEST_ID = 111
    private val ACTION_RESPAWN = "pushed.background_service.RESPAWN"

    fun enqueue(context: Context) {
        enqueue(context, 900000)
    }
    fun enqueue(context: Context, millis: Int) {

        val intent = Intent(context, WatchdogReceiver::class.java)
        intent.action = ACTION_RESPAWN
        val manager = context.getSystemService(ALARM_SERVICE) as AlarmManager

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        val pIntent = PendingIntent.getBroadcast(context, QUEUE_REQUEST_ID, intent, flags)
        manager.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + millis, pIntent)
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("WatchDog", "Alarm:${BackgroundService.active}")
        PushedService.addLogEvent(context, "Alarm:${BackgroundService.active}")
        if (intent?.action == ACTION_RESPAWN) {
            val pref = context?.getSharedPreferences("Pushed", Context.MODE_PRIVATE)
            try {
                context?.startService(Intent(context, BackgroundService::class.java))
                if (!BackgroundService.active) pref?.edit()?.putBoolean("restarted", true)?.apply()
                PushedService.addLogEvent(context, "Alarm start service")
            } catch (e: Exception) {
                PushedService.addLogEvent(context, "Alarm Err:${e.message}")
                if (!BackgroundService.active) {
                    pref?.edit()?.putBoolean("restarted", false)?.apply()
                    if (PushedJobService.startMyJob(context!!, 3000, 5000, 1))
                            PushedService.addLogEvent(context, "Sheduled")
                }
            }
        }
    }
}
