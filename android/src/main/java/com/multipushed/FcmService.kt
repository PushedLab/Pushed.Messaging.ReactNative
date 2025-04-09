package com.multipushed

import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject

class FcmService : FirebaseMessagingService() {
    private val tag = "FcmService"

    override fun onNewToken(token: String) {
        Log.d(tag, "Fcm Refreshed token: $token")
        PushedService.addLogEvent(this, "FCM change token: $token")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val pref = getSharedPreferences("Pushed", Context.MODE_PRIVATE)
        PushedService.addLogEvent(this, "Fcm Message: ${message.data}")
        val pushedMessage = JSONObject()
        val fcmData = message.data
        val traceId = fcmData["mfTraceId"]
        val messageId = fcmData["messageId"]
        val notification = fcmData["pushedNotification"]
        try {
            pushedMessage.put("data", JSONObject(fcmData["data"].toString()))
        } catch (e: Exception) {
            pushedMessage.put("data", fcmData["data"] ?: "")
            Log.d(tag, "Data is String")
        }
        if (messageId != null) pushedMessage.put("messageId", messageId)
        if (traceId != null) pushedMessage.put("mfTraceId", traceId)
        if (notification != null) pushedMessage.put("pushedNotification", notification)
        PushedService.addLogEvent(this, "Fcm PushedMessage: $pushedMessage")
        if (messageId != null && messageId != pref.getString("lastmessage", "")) {
            pref.edit().putString("lastmessage", messageId).apply()
            PushedService.confirmDelivered(this, messageId, "Fcm", traceId ?: "")
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
