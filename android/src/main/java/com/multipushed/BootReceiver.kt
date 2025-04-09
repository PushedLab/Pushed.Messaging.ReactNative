package com.multipushed

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build


class BootReceiver : BroadcastReceiver(){
    override fun onReceive(context: Context?, intent: Intent?) {
        PushedService.addLogEvent(context,"Boot:${BackgroundService.active}/${intent?.action}")
        if(intent?.action==Intent.ACTION_BOOT_COMPLETED || intent?.action=="android.intent.action.QUICKBOOT_POWERON"){
            val pref=context?.getSharedPreferences("Pushed", Context.MODE_PRIVATE)
            val secretPref=PushedService.getSecure(context!!)
            if(secretPref.getString("token","")!="") {
                try {
                    if (BackgroundService.active || Build.VERSION.SDK_INT <= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        context?.startService(Intent(context, BackgroundService::class.java))
                        if(!BackgroundService.active) pref?.edit()?.putBoolean("restarted", true)?.apply()
                        PushedService.addLogEvent(context,"Boot start service")
                    }
                } catch (e: Exception) {
                    PushedService.addLogEvent(context,"Boot Err:${e.message}")
                    /*if (!BackgroundService.active) {
                        pref?.edit()?.putBoolean("restarted", false)?.apply()
                        if(PushedJobService.startMyJob(context!!, 3000, 5000, 1))
                            PushedService.addLogEvent(context,"Sheduled")
                    }*/
                }
                /*if (!BackgroundService.active) {
                    pref?.edit()?.putBoolean("restarted", false)?.apply()
                    if(PushedJobService.startMyJob(context!!, 3000, 5000, 1))
                        PushedService.addLogEvent(context,"Sheduled")
                }*/
                if(!BackgroundService.active){
                    //pref?.edit()?.putBoolean("restarted",false)?.apply()
                    //if(PushedJobService.startMyJob(context!!,3000,5000,1))
                    //    PushedService.addLogEvent(context,"Alarm Sheduled")
                    PushedService.addLogEvent(context,"Boot start JobIntent")
                    val jobIntent = Intent(context, PushedJobIntentService::class.java)
                    PushedJobIntentService.enqueueWork(context!!, jobIntent)
                }
            }
        }
    }
}
