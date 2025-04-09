package com.multipushed

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.ActivityManager.RunningAppProcessInfo
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.StrictMode
import android.provider.Settings
import android.util.Base64
import android.util.Log 
import android.os.Handler 
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Observer
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.google.firebase.messaging.FirebaseMessaging
import com.huawei.hms.aaid.HmsInstanceId
import com.huawei.hms.api.HuaweiApiAvailability
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONArray
import org.json.JSONObject
import ru.rustore.sdk.pushclient.RuStorePushClient
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.Calendar

enum class Status(val value: Int){
    ACTIVE(0),OFFLINE(1),NOTACTIVE(2)
}

private val mainHandler = Handler(Looper.getMainLooper())

class PushedService(private val context : Context, messageReceiverClass: Class<*>?, channel:String?="messages",enableLogger:Boolean=false) {
    private val tag="Pushed Service"
    private val pref: SharedPreferences =context.getSharedPreferences("Pushed",Context.MODE_PRIVATE)
    private val secretPref: SharedPreferences = getSecure(context)
    private var serviceBinder: IBackgroundServiceBinder?=null
    private var messageHandler: ((JSONObject) -> Boolean)?=null
    private var statusHandler: ((Status) -> Unit)?=null
    private var sheduled=false
    var mShouldUnbind=false
    private var fcmToken:String?=null
    private var hpkToken:String?=null
    private var ruStoreToken:String?=null
    var status:Status=Status.NOTACTIVE
    var pushedToken:String?=null


    private val messageLiveData=MessageLiveData.getInstance()
    private var messageObserver:Observer<JSONObject>?=null
    private val binderId= (System.currentTimeMillis()/1000).toInt()
    private  val serviceConnection: ServiceConnection =object: ServiceConnection{
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            serviceBinder=IBackgroundServiceBinder.Stub.asInterface(service)
            try{
                val listener =object : IBackgroundService.Stub(){
                    override fun invoke(data: String?): Boolean {
                        return receiveData(JSONObject(data?:"{}"))
                    }

                    override fun stop() {
                        unbindService()
                    }

                }
                serviceBinder?.bind(binderId,listener)
            }
            catch (e:Exception){
                Log.e(tag,e.message.toString())
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            Log.d(tag,"on Disconnect")
            try{
                mShouldUnbind=false
                serviceBinder?.unbind(binderId)
                serviceBinder=null
            }
            catch (e:Exception){
                Log.e(tag,e.message.toString())
            }
        }

    }
    companion object{
        fun getSecure(context: Context):SharedPreferences{
            val masterKey: MasterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            return EncryptedSharedPreferences.create(
                context,
                "SecretPushed",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

        }
        private fun getBitmap(context: Context,uri:String?): Bitmap?{
            if(uri=="null") return null
            var bigIconRes=context.resources.getIdentifier(uri,"mipmap",context.packageName)
            if(bigIconRes==0)
                bigIconRes=context.resources.getIdentifier(uri,"drawable",context.packageName)
            if(bigIconRes!=0) return BitmapFactory.decodeResource(context.resources,bigIconRes)
            var bitmap: Bitmap?=null
            try {
                val url = URL(uri)
                val connection =
                    url.openConnection() as HttpURLConnection
                connection.doInput = true
                connection.connect()
                val stream = connection.inputStream
                bitmap = BitmapFactory.decodeStream(stream)
                Log.d("DemoApp", "Res: ${bitmap?.density}")
            }
            catch (e:Exception){
                addLogEvent(context, "Get Bitmap Error: ${e.message}")
            }
            return bitmap
        }
        fun showNotification(context: Context,pushedNotification: JSONObject){
            addLogEvent(context ,"Notification: $pushedNotification")
            val sp =context.getSharedPreferences("Pushed",Context.MODE_PRIVATE)
            val channel= sp.getString("channel",null) ?: return
            val id=sp.getInt("pushId",0)+1
            val body=(pushedNotification["Body"].toString())
            if(body=="null") return
            var iconRes=context.resources.getIdentifier(pushedNotification["Logo"].toString(),"mipmap",context.packageName)
            if(iconRes==0)
                iconRes=context.resources.getIdentifier(pushedNotification["Logo"].toString(),"drawable",context.packageName)
            if(iconRes==0)
                iconRes=context.applicationInfo.icon
            if(iconRes==0) return
            val bitmap= getBitmap(context,pushedNotification["Image"].toString())
            var intent=context.packageManager.getLaunchIntentForPackage(context.packageName)
            try{
                if(pushedNotification["Url"].toString() !="null"){
                    intent=Intent(Intent.ACTION_VIEW, Uri.parse(pushedNotification["Url"].toString()))
                    intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
            } catch (e:Exception){
                intent=context.packageManager.getLaunchIntentForPackage(context.packageName)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, flags)
            var title=""
            if(pushedNotification["Title"].toString()!="null")
                title=pushedNotification.getString("Title")
            try {
                val builder = NotificationCompat.Builder(context, channel).apply {
                    setSmallIcon(iconRes)
                    setContentTitle(title)
                    setContentText(body)
                    setAutoCancel(true)
                    setContentIntent(pendingIntent)
                    priority = NotificationCompat.PRIORITY_MAX
                    if(bitmap!=null){
                        setLargeIcon(bitmap)
                        setStyle(NotificationCompat.BigPictureStyle()
                            .bigPicture(bitmap)
                            .bigLargeIcon(null as Bitmap?))
                    }
                }
                with(NotificationManagerCompat.from(context)) {
                    notify(id, builder.build())
                }
                sp.edit().putInt("pushId",id).apply()
            }
            catch (e:SecurityException) {
                addLogEvent(context ,"Notify Security Error: ${e.message}")
            }
            catch (e:Exception) {
                addLogEvent(context ,"Notify Error: ${e.message}")
            }

        }


        fun addLogEvent(context: Context? ,event:String){
            val sp = context?.getSharedPreferences("Pushed", Context.MODE_PRIVATE)
            if(sp?.getBoolean("enablelogger",false)==true) {
                    val date: String = Calendar.getInstance().time.toString()
                    val fEvent = "$date: $event\n"
                    Log.d("PushedLogger", fEvent)
                    val log = sp.getString("log", "")
                    sp.edit().putString("log", log + fEvent).apply()
            }
        }
        fun getLog(context: Context? ):String{
            val sp =context?.getSharedPreferences("Pushed",Context.MODE_PRIVATE)
            if(sp!=null) return sp.getString("log","")?:""
            return ""
        }
        fun confirmDelivered(context: Context? ,messageId :String,transport:String,traceId:String){
            val sp =context?.getSharedPreferences("Pushed",Context.MODE_PRIVATE)
            addLogEvent(context,"Confirm: $messageId/$transport")
            val token: String = sp?.getString("token",null) ?: return
            val basicAuth = "Basic ${Base64.encodeToString("$token:$messageId".toByteArray(),Base64.NO_WRAP)}"
            val body="".toRequestBody("application/json; charset=utf-8".toMediaType())
            val client = OkHttpClient()
            val request = Request.Builder()
                .url("https://pub.pushed.ru/v2/confirm?transportKind=$transport")
                .addHeader("Authorization", basicAuth)
                .addHeader("mf-trace-id",traceId)
                .post(body)
                .build()
            client.newCall(request).enqueue(object :Callback{
                override fun onFailure(call: Call, e: IOException) {
                    addLogEvent(context,"Confirm failure: ${e.message}")
                }

                override fun onResponse(call: Call, response: Response) {
                    if(response.isSuccessful){
                        val responseBody= response.body?.string()
                        addLogEvent(context,"Confirm response: $responseBody")
                    }
                    else
                        addLogEvent(context,"Confirm code: ${response.code}")
                }

            })
        }
        fun isApplicationForeground(context: Context): Boolean {
            val keyguardManager =
                context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager?
            if (keyguardManager != null && keyguardManager.isKeyguardLocked) {
                return false
            }
            val activityManager =
                context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager?
                    ?: return false
            val appProcesses = activityManager.runningAppProcesses ?: return false
            val packageName = context.packageName
            for (appProcess in appProcesses) {
                if (appProcess.importance == RunningAppProcessInfo.IMPORTANCE_FOREGROUND && appProcess.processName == packageName) {
                    return true
                }
            }
            return false
        }

    }
    init{
        pushedToken=secretPref.getString("token",null)
        fcmToken=secretPref.getString("fcmtoken",null)
        ruStoreToken=secretPref.getString("rustoretoken",null)
        hpkToken=secretPref.getString("hpktoken",null)
        pushedToken=getNewToken()
        addLogEvent(context,"Pushed Token: $pushedToken")
        if(pushedToken!=null){
            status=Status.OFFLINE
            pref.edit().putString("listenerclass",messageReceiverClass?.name).apply()
            pref.edit().putString("channel",channel).apply()
            pref.edit().putBoolean("enablelogger",enableLogger).apply()
            val firstRun=pref.getBoolean("firstrun", true)
            val battaryIntent= Intent()
            battaryIntent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            battaryIntent.data = Uri.parse("package:${context.packageName}")
            if(channel!=null){
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val notificationChannel= NotificationChannel(channel,"Messages", NotificationManager.IMPORTANCE_HIGH)
                    val notificationManager=context.getSystemService(NotificationManager::class.java)
                    notificationManager.createNotificationChannel(notificationChannel)
                }
                if(firstRun)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(context,
                                Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            (context as Activity).requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                        }
                    }
            }
            val pm=context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if(!pm.isIgnoringBatteryOptimizations(context.packageName) && firstRun) {
                context.startActivity(battaryIntent)
            }
            pref.edit().putBoolean("firstrun",false).apply()
            messageObserver = Observer<JSONObject> { message: JSONObject? ->
                if(messageHandler==null || messageHandler?.invoke(message!!)==false){
                    try{
                        val notification=JSONObject(message!!["pushedNotification"].toString())
                        showNotification(context,notification )
                    }
                    catch (e:Exception){
                        addLogEvent(context,"Notification error: ${e.message}")
                    }
                    if(messageReceiverClass!=null){
                        val intent = Intent(context, messageReceiverClass)
                        intent.action = "ru.pushed.action.MESSAGE"
                        intent.putExtra("message",message.toString())
                        context.sendBroadcast(intent)
                    }
                }
            }
            mainHandler.post { // ✅ Move observeForever() to the UI thread
                messageLiveData?.observeForever(messageObserver!!)
            }
            //Fcm

            try{
                Log.d("BackgroundService", "connecting to fcm")
                FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                    if (task.isSuccessful) { 
                        Log.d("BackgroundService","FCM Token: ${task.result}")
                        addLogEvent(context, "Fcm Token: ${task.result}")
                        if (fcmToken != task.result) {
                            fcmToken = task.result
                            getNewToken()
                        }
                    }
                    else{ 
                         Log.d("BackgroundService", "cant inti fcm  ")
                        addLogEvent(context, "Cant init Fcm")
                    }
                }
            }
            catch (e:Exception){ 
                 Log.d("BackgroundService", "Fcm init Error: ${e.message}")
                addLogEvent(context, "Fcm init Error: ${e.message}")
            }

            //RuStore
            try {
                RuStorePushClient.getToken().addOnSuccessListener { token: String ->
                    addLogEvent(context, "RuStore Token: $token")
                    if(token!=ruStoreToken){
                        ruStoreToken = token
                        getNewToken()
                    }
                }
            } catch (e: Exception) {
                addLogEvent(context, "RuStore init Error: ${e.message}")
            }

            //Hpk
            try{
                val hmsResult=HuaweiApiAvailability.getInstance().isHuaweiMobileServicesAvailable(context)
                addLogEvent(context, "HMS Core: $hmsResult")
                if(hmsResult==0) {
                    object : Thread(){
                        override fun run() {
                            try{
                                val token = HmsInstanceId.getInstance(context).getToken("","HCM")
                                addLogEvent(context, "Hpk Token: $token")
                                if(token!=hpkToken) {
                                    hpkToken=token
                                    getNewToken()
                                }
                            } catch(e: Exception){
                                addLogEvent(context, "Hpk init Error: ${e.message}")
                            }
                        }
                    }.start()
                }
            } catch (e:Exception){
                addLogEvent(context, "HMS Core init Error: ${e.message}")
            }
        }
    }
    fun setStatusHandler(handler: (Status)->Unit){
        statusHandler=handler
    }
    fun unbindService(){
        messageHandler=null
        if(mShouldUnbind){
            mShouldUnbind=false
            context.unbindService(serviceConnection)
            serviceBinder?.unbind(binderId)
        }
    }
    fun reconnect(){
        serviceBinder?.invoke("{\"method\":\"restart\"}")
    }
    fun receiveData(data:JSONObject): Boolean{

        addLogEvent(context,"Message Service($binderId): $data")
        if(data.has("ServiceStatus")){
            if(status!= Status.valueOf(data.getString("ServiceStatus"))){
                status=Status.valueOf(data.getString("ServiceStatus"))
                addLogEvent(context,"Status changed: $status")
                statusHandler?.invoke(status)

            }

        }
        else return messageHandler?.invoke(data)?:false
        return true

    }
    fun start(onMessage:((JSONObject)->Boolean)?):String? {
        if(pushedToken==null) return null
        messageHandler=onMessage
        val serviceIntent=Intent(context,BackgroundService::class.java)
        serviceIntent.putExtra("binder_id", binderId)
        context.startService(serviceIntent)
        mShouldUnbind=context.bindService(serviceIntent,serviceConnection,Context.BIND_AUTO_CREATE)
        if(!sheduled){
            sheduled=true
            PushedJobIntentService.deactivateJob()
            val jobIntent = Intent(context, PushedJobIntentService::class.java)
            PushedJobIntentService.enqueueWork(context, jobIntent)
            //PushedJobService.stopActiveJob(context)
            PushedJobService.startMyJob(context,3000,5000,1)
        }
        pref.edit().putBoolean("restarted",false).apply()
        return pushedToken
    }
    private fun getNewToken():String?{
        val policy= StrictMode.ThreadPolicy.Builder().permitAll().build()
        StrictMode.setThreadPolicy(policy)
        val deviceSettings= JSONArray()// mutableListOf<JSONObject>()
        if(fcmToken?.isNotEmpty()==true) deviceSettings.put(JSONObject().put("deviceToken",fcmToken).put("transportKind","Fcm"))
        if(hpkToken?.isNotEmpty()==true) deviceSettings.put(JSONObject().put("deviceToken",hpkToken).put("transportKind","Hpk"))
        if(ruStoreToken?.isNotEmpty() == true) deviceSettings.put(JSONObject().put("deviceToken",ruStoreToken).put("transportKind","RuStore"))
        val content=JSONObject("{\"clientToken\": \"${pushedToken?:""}\"}")
        if(deviceSettings.length()>0) content.put("deviceSettings",deviceSettings)
        val body= content.toString().toRequestBody("application/json; charset=utf-8".toMediaType())
        addLogEvent(context,"Content: $content")
        var result:String?=null
        val client = OkHttpClient()
        val request = Request.Builder()
            .url("https://sub.pushed.ru/v2/tokens")
            .post(body)
            .build()
        try {
            val response=client.newCall(request).execute()
            if(response.isSuccessful)
            {

                val responseBody= response.body?.string()
                addLogEvent(context,"Get Token response: $responseBody")
                result = try{
                    val model=JSONObject(responseBody!!)["model"] as JSONObject
                    addLogEvent(context,"model: $model")
                    model["clientToken"] as String?
                } catch (e:Exception){
                    addLogEvent(context,"Convert ERR: ${e.message}")
                    null
                }
            }

        }
        catch (e: IOException){
            addLogEvent(context,"Get Token Err: ${e.message}")
        }
        if(result!=null && result!=""){ 
            Log.d("BackgroundService", "${result}")
            secretPref.edit().putString("token",result).apply()
            if(fcmToken!=null) secretPref.edit().putString("fcmtoken",fcmToken).apply()
            if(hpkToken!=null) secretPref.edit().putString("hpktoken",hpkToken).apply()
            if(ruStoreToken!=null) secretPref.edit().putString("rustoretoken",ruStoreToken).apply()
            pushedToken=result
        }
        else result=pushedToken
        return result
    }

}
