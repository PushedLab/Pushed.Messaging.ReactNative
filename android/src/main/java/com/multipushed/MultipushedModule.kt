package com.multipushed

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.turbomodule.core.interfaces.TurboModule
import android.app.Activity
import android.util.Log

@ReactModule(name = MultipushedModule.NAME)
class MultipushedModule(
        private val reactContext: ReactApplicationContext,
        private val activity: Activity?
) : NativeMultipushedSpec(reactContext), TurboModule { // ✅ Ensure it extends NativeMultipushedSpec

  private var pushedService: PushedService? = null

  override fun getName(): String {
    return NAME
  }


  @ReactMethod
  override fun startService(promise: Promise) {
    try {
      // initialize
      if (activity == null) {
        promise.reject("NO_ACTIVITY", "No Activity found")
        return
      }
      pushedService = PushedService(activity, null)

      // start
      pushedService = PushedService(activity, null)
    // Передаем коллбэк при старте
      val token = pushedService?.start { messageJson ->
        sendEvent("PUSH_RECEIVED", messageJson.toString())
        false
      }
      promise.resolve(token)
    } catch (e: Exception) {
      promise.reject("SERVICE_ERROR", e)
    }
  }

  private fun sendEvent(eventName: String, data: String) {
    reactApplicationContext
            .getJSModule(
                    com.facebook.react.modules.core.DeviceEventManagerModule
                                    .RCTDeviceEventEmitter::class
                            .java
            )
            .emit(eventName, data)
  }

  companion object {
    const val NAME = "Multipushed"
  }
}
