package com.multipushed

import androidx.lifecycle.LiveData
import org.json.JSONObject

class MessageLiveData : LiveData<JSONObject>() {
    companion object {
        private var instance: MessageLiveData? = null

        fun getInstance(): MessageLiveData? {
            if (instance == null) {
                instance = MessageLiveData()
            }
            return instance
        }
    }

    fun postRemoteMessage(message: JSONObject?) {
        postValue(message)
    }
}
