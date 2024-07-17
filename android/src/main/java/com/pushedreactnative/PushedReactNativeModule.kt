package com.pushedreactnative

import android.util.Log
import androidx.annotation.Nullable
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import org.json.JSONException
import org.json.JSONObject
import ru.pushed.messaginglibrary.PushedService

class PushedReactNativeModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {
  private val mReactContext = reactContext

  override fun getName(): String {
    return NAME
  }

  private fun sendEvent(eventName: String, @Nullable params: JSONObject?) {
    val payload = Arguments.createMap()

    // Convert JSONObject to WritableMap
    if (params != null) {
      try {
        val keys = params.keys()
        while (keys.hasNext()) {
          val key = keys.next()
          val value = params.get(key)
          when (value) {
            is String -> payload.putString(key, value)
            is Int -> payload.putInt(key, value)
            is Double -> payload.putDouble(key, value)
            is Boolean -> payload.putBoolean(key, value)
            is JSONObject -> payload.putMap(key, jsonToWritableMap(value))
            else -> {
              Log.w("PushedReactNative", "Unhandled data type in JSON object for key: $key")
            }
          }
        }
      } catch (e: JSONException) {
        Log.e("PushedReactNative", "Failed to convert JSONObject to WritableMap", e)
      }
    }

    mReactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(eventName, payload)
    Log.d("PushedReactNative", "Event sent: $eventName with params: $params")
  }

  private var pushedService: PushedService? = null

  @ReactMethod
  fun startService(serviceName: String, promise: Promise) {
    Log.d("PushedReactNative", "Initializing PushedService with serviceName: $serviceName")

    if (pushedService == null) {
      try {
        pushedService = currentActivity?.let {
          PushedService(
            it, serviceName, "", 0,
            PushedBackgroundService::class.java
          )
        }
        Log.i("PushedReactNative", "PushedService initialized successfully")
      } catch (e: Exception) {
        Log.e("PushedReactNative", "Failed to initialize PushedService", e)
        promise.reject("InitializationError", "Failed to initialize PushedService", e)
        return
      }
    }

    try {
      val token: String = pushedService!!.start { message ->
        sendEvent(PushedEventType.PUSH_RECEIVED.name, message)
        true
      }.toString()
      Log.i("PushedReactNative", "PushedService started with token: $token")
      promise.resolve(token)
    } catch (e: Exception) {
      Log.e("PushedReactNative", "Failed to start PushedService", e)
      promise.reject("StartError", "Failed to start PushedService", e)
    }
  }

  @ReactMethod
  fun stopService(promise: Promise) {
    Log.d("PushedReactNative", "Stopping PushedService")

    if (pushedService == null) {
      Log.e("PushedReactNative", "PushedService is not initialized")
      promise.reject("ServiceError", "PushedService is not initialized")
      return
    }

    try {
      pushedService!!.unbindService()
      Log.i("PushedReactNative", "PushedService stopped successfully")
      promise.resolve("Service stopped")
    } catch (e: Exception) {
      Log.e("PushedReactNative", "Failed to stop PushedService", e)
      promise.reject("StopError", "Failed to stop PushedService", e)
    }
  }

  companion object {
    const val NAME = "PushedReactNative"
  }

  @ReactMethod
  fun addListener(eventName: String) {
    Log.d("PushedReactNative", "Listener added for event: $eventName")
  }

  @ReactMethod
  fun removeListeners(count: Int) {
    Log.d("PushedReactNative", "Listeners removed, count: $count")
  }

  // Helper function to convert JSONObject to WritableMap
  private fun jsonToWritableMap(jsonObject: JSONObject): WritableMap {
    val map = Arguments.createMap()
    val keys = jsonObject.keys()
    while (keys.hasNext()) {
      val key = keys.next()
      val value = jsonObject.get(key)
      when (value) {
        is String -> map.putString(key, value)
        is Int -> map.putInt(key, value)
        is Double -> map.putDouble(key, value)
        is Boolean -> map.putBoolean(key, value)
        is JSONObject -> map.putMap(key, jsonToWritableMap(value))
        else -> {
          Log.w("PushedReactNative", "Unhandled data type in JSON object for key: $key")
        }
      }
    }
    return map
  }
}
