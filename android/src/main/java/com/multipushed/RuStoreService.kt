package com.multipushed

import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import ru.rustore.sdk.pushclient.messaging.model.RemoteMessage
import ru.rustore.sdk.pushclient.messaging.service.RuStoreMessagingService

class RuStoreService : RuStoreMessagingService() {
    private val tag = "RuStoreService"
    override fun onMessageReceived(message: RemoteMessage) {
        val pref = getSharedPreferences("Pushed", Context.MODE_PRIVATE)
        PushedService.addLogEvent(this, "RuStore Message: ${message.data}")
        val pushedMessage = JSONObject()
        val ruStoreData = message.data
        val traceId = ruStoreData["mfTraceId"]
        val messageId = ruStoreData["messageId"]
        val notification = ruStoreData["pushedNotification"]
        try {
            pushedMessage.put("data", JSONObject(ruStoreData["data"].toString()))
        } catch (e: Exception) {
            pushedMessage.put("data", ruStoreData["data"] ?: "")
            Log.d(tag, "Data is String")
        }
        if (messageId != null) pushedMessage.put("messageId", messageId)
        if (traceId != null) pushedMessage.put("mfTraceId", traceId)
        if (notification != null) pushedMessage.put("pushedNotification", notification)

        PushedService.addLogEvent(this, "RuStore PushedMessage: $pushedMessage")
        if (messageId != null && messageId != pref.getString("lastmessage", "")) {
            pref.edit().putString("lastmessage", messageId).apply()
            PushedService.confirmDelivered(this, messageId, "RuStore", traceId ?: "")
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
        super.onMessageReceived(message)
    }
}
