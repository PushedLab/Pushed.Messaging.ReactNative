package com.multipushed

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

import androidx.core.app.JobIntentService
import org.json.JSONObject

class PushedJobIntentService : JobIntentService() {
    private var messageListener:MessageListener?=null
    private lateinit var pref: SharedPreferences
    private lateinit var secretPref: SharedPreferences
    private val watchdogReceiver=WatchdogReceiver()

    companion object {
        val JOB_ID = 2
        var num=0
        var activeJob:PushedJobIntentService?=null
        fun enqueueWork(context: Context, intent: Intent) {
            enqueueWork(context, PushedJobIntentService::class.java, JOB_ID, intent)
        }
        fun deactivateJob(){
            activeJob?.messageListener?.deactivate() 
            Log.d("BackgroundService", "onDeactivate")

        }
    }
    override fun onHandleWork(intent: Intent) {
        watchdogReceiver.enqueue(this,60000)
        //activeJob=this
        if(BackgroundService.active){
            PushedService.addLogEvent(this,"Intent Job wath")
            //Thread.sleep(15000)
            watchdogReceiver.enqueue(this,15000)
            return
        }
        watchdogReceiver.enqueue(this,60000)
        pref = getSharedPreferences("Pushed", MODE_PRIVATE)
        secretPref=PushedService.getSecure(this)
        messageListener= activeJob?.messageListener
        activeJob=this
        PushedService.addLogEvent(this,"Intent Job: ${num++}")
        if(messageListener!=null){
            PushedService.addLogEvent(this,"Intent Job service already started")
            messageListener!!.disconnect()
        }
        else{
            val token=secretPref.getString("token",null)
            if(token!=null){
                pref.edit().putBoolean("restarted",true).apply()
                messageListener=MessageListener("wss://sub.pushed.ru/v2/open-websocket/$token",this){message->
                    PushedService.addLogEvent(this,"Intent Job Background message: $message")
                    if(!message.has("ServiceStatus")){
                        if(message["messageId"]!=pref.getString("lastmessage","")){
                            pref.edit().putString("lastmessage",message["messageId"].toString()).apply()
                            try{
                                val notification= JSONObject(message["pushedNotification"].toString())
                                PushedService.showNotification(this,notification )
                            }
                            catch (e:Exception){
                            PushedService.addLogEvent(this,"Notification error: ${e.message}")
                            }
                            val listenerClassName= pref.getString("listenerclass",null)
                            if(listenerClassName!=null){
                                val messageIntent = Intent(applicationContext, Class.forName(listenerClassName))
                                messageIntent.action = "ru.pushed.action.MESSAGE"
                                messageIntent.putExtra("message",message.toString())
                                sendBroadcast(messageIntent)
                            }
                        }
                    }
                }
            }
        }
        //Thread.sleep(540000)
        Thread.sleep(120000)

    }

    override fun onDestroy() {
        PushedService.addLogEvent(this,"Intent Job destroyed")
        super.onDestroy()
        //activeJob?.messageListener?.deactivate()
        //activeJob=null
        //PushedService.addLogEvent(this,"Intent Job destroyed")
        //val jobIntent = Intent(this, PushedJobIntentService::class.java)
        //enqueueWork(this, jobIntent)
    }
}
