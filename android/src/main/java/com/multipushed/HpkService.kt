package com.multipushed

import android.content.Context
import android.content.Intent
import android.util.Log
import com.huawei.hms.push.HmsMessageService
import com.huawei.hms.push.RemoteMessage
import org.json.JSONObject

class HpkService : HmsMessageService() {
    private val tag = "HpkService"

    override fun onMessageReceived(message: RemoteMessage?) {
        super.onMessageReceived(message)
        val hpkData = message?.dataOfMap
        val pref = getSharedPreferences("Pushed", Context.MODE_PRIVATE)
        PushedService.addLogEvent(this, "Hpk Message: $hpkData")
        val notification = hpkData?.get("pushedNotification")
        val pushedMessage = JSONObject()
        val traceId = hpkData?.get("mfTraceId")
        val messageId = hpkData?.get("messageId")
        try {
            pushedMessage.put("data", JSONObject(hpkData?.get("data") ?: "{}"))
        } catch (e: Exception) {
            pushedMessage.put("data", hpkData?.get("data") ?: "")
            Log.d(tag, "Data is String")
        }
        if (messageId != null) pushedMessage.put("messageId", messageId)
        if (traceId != null) pushedMessage.put("mfTraceId", traceId)
        if (notification != null) pushedMessage.put("pushedNotification", notification)
        PushedService.addLogEvent(this, "Hpk PushedMessage: $pushedMessage")
        if (messageId != null && messageId != pref.getString("lastmessage", "")) {
            pref.edit().putString("lastmessage", messageId).apply()
            PushedService.confirmDelivered(this, messageId, "Hpk", traceId ?: "")
            if (PushedService.isApplicationForeground(this)) {
                MessageLiveData.getInstance()?.postRemoteMessage(pushedMessage)
            } else {
                val listenerClassName = pref.getString("listenerclass", null)
                if (notification != null)
                        PushedService.showNotification(this, JSONObject(notification))
                if (listenerClassName != null) {
                    val intent = Intent(applicationContext, Class.forName(listenerClassName))
                    intent.action = "com.multipushed.action.MESSAGE"
                    intent.putExtra("message", pushedMessage.toString())
                    sendBroadcast(intent)
                }
            }
        }
    }

    override fun onNewToken(token: String?) {
        Log.d(tag, "Hpk Refreshed token: $token")
        PushedService.addLogEvent(this, "Hpk change token: $token")
        super.onNewToken(token)
    }
}
