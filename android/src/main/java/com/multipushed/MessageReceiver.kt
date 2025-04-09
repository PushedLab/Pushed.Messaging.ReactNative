package com.multipushed

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject

open class MessageReceiver : BroadcastReceiver() {
    private val tag = "MessageReceiver"
    private val ACTION_MESSAGE = "com.multipushed.action.MESSAGE"
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == ACTION_MESSAGE)
                onBackgroundMessage(context, JSONObject(intent.getStringExtra("message") ?: "{}"))
    }
    open fun onBackgroundMessage(context: Context?, message: JSONObject) {
        Log.d(tag, "Background message: $message")
    }
}
