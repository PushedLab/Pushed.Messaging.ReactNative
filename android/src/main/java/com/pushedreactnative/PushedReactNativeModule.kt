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
import com.facebook.react.bridge.UiThreadUtil
import android.os.Handler
import android.os.Looper

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

  // When true, the native SDK draws the notification itself, which also makes it honour
  // `pushedNotification.url` on tap (PushedClickActivity -> ACTION_VIEW). Off by default:
  // existing integrations render the banner in JS and would otherwise get a duplicate.
  private var useNativeNotifications: Boolean = false

  @ReactMethod
  fun startService(serviceName: String, applicationId: String?, promise: Promise) {
    Log.d("PushedReactNative", "Initializing PushedService")
    startServiceWithActivity(applicationId, promise, retriesLeft = 20)
  }

  // On cold start startService() can be called from JS before the Activity has
  // attached to the React context (currentActivity is still null). Retry briefly
  // instead of failing immediately, since the attach normally happens within ms.
  private fun startServiceWithActivity(applicationId: String?, promise: Promise, retriesLeft: Int) {
    val currentActivity = currentActivity
    if (currentActivity == null) {
      if (retriesLeft <= 0) {
        promise.reject("NO_ACTIVITY", "Current activity is null")
        return
      }
      Handler(Looper.getMainLooper()).postDelayed({
        startServiceWithActivity(applicationId, promise, retriesLeft - 1)
      }, 100)
      return
    }

    UiThreadUtil.runOnUiThread {
      // 1. Инициализируем сервис (без try/catch, чтобы видеть реальные ошибки и не скрывать их)
      if (pushedService == null) {
        pushedService = PushedService(
          currentActivity,
          PushedBackgroundService::class.java,
          applicationId = applicationId,
          currentSdk = "React-Native 1.1.8"
        )

        // Токен может быть ещё не готов на момент первого запуска (получается
        // асинхронно). Когда статус сервиса меняется, токен уже точно есть —
        // шлём его в JS отдельным событием, чтобы UI обновился без перезахода.
        pushedService?.setStatusHandler { _ ->
          val updatedToken = pushedService?.pushedToken
          if (!updatedToken.isNullOrEmpty()) {
            val payload = JSONObject()
            payload.put("token", updatedToken)
            sendEvent(PushedEventType.TOKEN_UPDATED.name, payload)
          }
        }
      }

      // 2. Запускаем сервис и оборачиваем **только** получение токена в try/catch
      try {
        val token: String? = pushedService?.start { message ->
          sendEvent(PushedEventType.PUSH_RECEIVED.name, message)
          // The return value tells the native SDK whether we handled the message ourselves.
          // `true` suppresses its notification — that is the default, because the banner is
          // normally drawn in JS. Returning `false` lets the SDK show it and, with it, follow
          // `pushedNotification.url` when the user taps.
          !useNativeNotifications
        }

        Log.i("PushedReactNative", "PushedService started with token: $token")
        promise.resolve(token)
      } catch (e: Exception) {
        Log.e("PushedReactNative", "Failed to start PushedService", e)
        promise.reject("SERVICE_ERROR", "Failed to start PushedService", e)
      }
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

  /// Enable before `startService` to let the native SDK render notifications. Needed if you
  /// want `pushedNotification.url` to open on tap without handling it in JS; note that
  /// `PUSH_RECEIVED` still fires, so don't also display the banner yourself.
  @ReactMethod
  fun setUseNativeNotifications(enabled: Boolean) {
    useNativeNotifications = enabled
    Log.d("PushedReactNative", "useNativeNotifications=$enabled")
  }

  // Optional: accept applicationId from JS for future use (currently ignored on Android)
  @ReactMethod
  fun setApplicationId(applicationId: String) {
    Log.d("PushedReactNative", "Received applicationId: $applicationId (currently unused on Android)")
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
