package com.pushedreactnative

import android.util.Log
import org.json.JSONObject
import ru.pushed.messaginglibrary.BackgroundService


class PushedBackgroundService : BackgroundService() {
  override fun onBackgroundMessage(message: JSONObject) {
    Log.d("PushedBackgroundService", "PushedService message: $message")
  }
}
