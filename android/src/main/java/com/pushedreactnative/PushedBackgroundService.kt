package com.pushedreactnative

import android.util.Log
import org.json.JSONObject
import ru.pushed.messaginglibrary.BackgroundService


class PushedBackgroundService : BackgroundService() {
  override fun onBackgroundMessage(message: JSONObject) {
    // Call the default implementation (shows notification via PushedService)
    super.onBackgroundMessage(message)

    // Optional: keep custom logging for debug purposes
    Log.d("PushedBackgroundService", "PushedService message: $message")
  }
}
