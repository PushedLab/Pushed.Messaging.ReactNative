package com.multipushed

import android.content.Context

import android.os.PowerManager
import android.util.Log
import okhttp3.*
import okio.ByteString
import okio.ByteString.Companion.encode
import org.json.JSONObject
import java.util.Calendar
import java.util.concurrent.TimeUnit

class MessageListener (private val url : String, private val context: Context, var listener: (JSONObject)->Unit) : WebSocketListener(){
    private val tag="MessageListener"
    private val client: OkHttpClient = OkHttpClient.Builder()
        .readTimeout(0,  TimeUnit.MILLISECONDS)
        .build()
    private var wakeLock: PowerManager.WakeLock?=null
    private var activeWebSocket: WebSocket?=null
    private var connected = false
    private var active=false
    private var connectivityActive=true
    private val connectivity = Connectivity(context)
    private var needReconnect=true
    private var retryCount=0
    private var lastConnected:Long=0
    init {

        val mgr=context.getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock=mgr.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,this::class.java.name)
        wakeLock?.setReferenceCounted(true)
        lock()
        connectivity.setListener {
            if(connectivityActive){
                Log.d(tag,"Connectivity: $it")
                PushedService.addLogEvent(context,"Connectivity: $it")
                if(it==Connectivity.Status.WIFI) disconnect()
                connected = it != Connectivity.Status.NONE
                connect()
            }
        }
    }
    fun setMessageListener(newListener: (JSONObject)->Unit){
        listener=newListener
    }
    private fun connect() {
        if(!connected) {
            unLock()
            return
        }
        if(active) return
        active=true
        disconnect()
        val request= Request.Builder()
            .url(url)
            .build()
        client.newWebSocket(request,this)
    }
    fun disconnect(dontReconnect :Boolean = false,forceDisconnect:Boolean = false){
        needReconnect=!dontReconnect
        if(activeWebSocket==null && needReconnect) connect()
        else if(!forceDisconnect && Calendar.getInstance().timeInMillis-lastConnected<600000) {
            PushedService.addLogEvent(context,"Reconnect postponed")
            return
        }
        else activeWebSocket?.cancel()


    }
    fun deactivate()
    {
        connectivityActive=false
        disconnect(true,true)
    }
    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
        lock()
        val message=bytes.utf8()
        Log.d(tag,"onMessage: $message")
        PushedService.addLogEvent(context,"onMessage: $message")
        listener(JSONObject("{\"ServiceStatus\":\"ACTIVE\"}"))
        if(message!="ONLINE") {
            val payLoad=JSONObject(message)
            val response=JSONObject()
            response.put("messageId",payLoad["messageId"])
            response.put("mfTraceId",payLoad["mfTraceId"])
            activeWebSocket?.send(response.toString().encode(Charsets.UTF_8))
            try {
                payLoad.put("data",JSONObject(payLoad["data"].toString()))
            }
            catch(e: Exception) {
                Log.d(tag,"Data is String")
            }
            listener(payLoad)
        }
        Thread.sleep(3000)
        unLock()
    }

    override fun onOpen(webSocket: WebSocket, response: Response) {
        Log.d(tag,"webSocked Open")
        PushedService.addLogEvent(context,"webSocked Open")
        activeWebSocket=webSocket
        retryCount=0
        lastConnected=Calendar.getInstance().timeInMillis
    }

    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
        Log.d(tag,"webSocked Closing")
        PushedService.addLogEvent(context,"webSocked Closing")

        disconnect()

    }

    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        lock()
        Log.d(tag,"Err: ${t.message}")
        PushedService.addLogEvent(context,"Err: ${t.message}")
        listener(JSONObject("{\"ServiceStatus\":\"OFFLINE\"}"))
        activeWebSocket=null
        active=false
        retryCount++
        lastConnected=0
        Thread.sleep(retryCount*1000L)
        if(retryCount>=10) needReconnect=false
        if(needReconnect) connect()
    }
    private fun lock(){
        if(wakeLock?.isHeld == false){
            Log.d(tag,"Lock")
            PushedService.addLogEvent(context,"Lock")
            wakeLock?.acquire(60*1000)
        }
    }
    private fun unLock(){
        if(wakeLock?.isHeld == true){
            PushedService.addLogEvent(context,"Unlock")
            Log.d(tag,"Unlock")
            wakeLock?.release()
        }
    }


}
