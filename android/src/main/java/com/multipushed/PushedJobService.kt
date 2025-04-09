package com.multipushed

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import org.json.JSONObject

class PushedJobService : JobService() {

    private var activeJob: JobParameters? = null
    private var messageListener: MessageListener? = null
    private lateinit var pref: SharedPreferences

    companion object {
        @Volatile private var activeService: PushedJobService? = null
        private const val tag = "BackgroundService"
        fun startMyJob(context: Context, minDelay: Int, deadDelay: Int, jobId: Int): Boolean {
            val jobService = ComponentName(context, PushedJobService::class.java)
            val exerciseJobBuilder = JobInfo.Builder(jobId, jobService)
            exerciseJobBuilder.setMinimumLatency(minDelay.toLong())
            exerciseJobBuilder.setOverrideDeadline(deadDelay.toLong())
            exerciseJobBuilder.setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            exerciseJobBuilder.setRequiresDeviceIdle(false)
            exerciseJobBuilder.setRequiresCharging(false)
            exerciseJobBuilder.setPersisted(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                exerciseJobBuilder.setPriority(JobInfo.PRIORITY_HIGH)
            }
            exerciseJobBuilder.setBackoffCriteria(20000, JobInfo.BACKOFF_POLICY_LINEAR)
            Log.d(tag, "scheduleJob: adding job to scheduler")
            val jobScheduler = context.getSystemService(JOB_SCHEDULER_SERVICE) as JobScheduler
            return jobScheduler.schedule(exerciseJobBuilder.build()) == JobScheduler.RESULT_SUCCESS
        }
    }
    override fun onStartJob(jobParams: JobParameters?): Boolean {
        Log.d(tag, "Start Job ${jobParams?.jobId}")
        PushedService.addLogEvent(this, "Start Job ${jobParams?.jobId}:${BackgroundService.active}")
        pref = getSharedPreferences("Pushed", MODE_PRIVATE)
        val restarted = pref.getBoolean("restarted", false)
        if (restarted) return false
        if (BackgroundService.active) {
            if (startMyJob(applicationContext, 10000, 15000, (jobParams?.jobId ?: 0) + 1)) {
                Log.d(tag, "Scheduled")
                PushedService.addLogEvent(this, "Sheduled")
            }
            return false
        }
        try {
            val token = pref.getString("token", "")
            if (token!!.isNotEmpty()) {
                applicationContext.startService(
                        Intent(applicationContext, BackgroundService::class.java)
                )
            }
            pref.edit().putBoolean("restarted", true).apply()
            return false
        } catch (e: Exception) {
            PushedService.addLogEvent(this, "Exception: ${e.message}")
            Log.d(tag, "Exception: ${e.message}")
        }
        if (activeService?.messageListener != null) {
            Log.d(tag, "Job service already started")
            PushedService.addLogEvent(this, "Job service already started")
            messageListener?.disconnect()
            return false
        }
        activeService = this
        activeJob = jobParams
        val token = pref.getString("token", null)
        Log.d(tag, "Token: $token")
        if (token != null) {
            messageListener =
                    MessageListener("wss://sub.pushed.ru/v2/open-websocket/$token", this) { message
                        ->
                        Log.d(tag, "Job Background message: $message")
                        if (!message.has("ServiceStatus")) {
                            if (message["messageId"] != pref.getString("lastmessage", "")) {
                                pref.edit()
                                        .putString("lastmessage", message["messageId"].toString())
                                        .apply()
                                try {
                                    val notification =
                                            JSONObject(message["pushedNotification"].toString()) 
                                    Log.d(tag, message["pushedNotification"].toString())       
                                    PushedService.showNotification(this, notification)
                                } catch (e: Exception) {
                                    PushedService.addLogEvent(
                                            this,
                                            "Notification error: ${e.message}"
                                    )
                                }
                                val listenerClassName = pref.getString("listenerclass", null)
                                if (listenerClassName != null) {
                                    val intent =
                                            Intent(
                                                    applicationContext,
                                                    Class.forName(listenerClassName)
                                            )
                                    intent.action = "com.multipushed.action.MESSAGE"
                                    intent.putExtra("message", message.toString())
                                    sendBroadcast(intent)
                                }
                            }
                        }
                    }
            return true
        }
        return false
    }

    override fun onStopJob(jobParams: JobParameters?): Boolean {
        PushedService.addLogEvent(this, "Start Job")
        if (activeService == this) activeService = null
        Log.d(tag, "Stop Job")
        messageListener?.disconnect(true)
        messageListener = null
        if (!BackgroundService.active)
                if (startMyJob(applicationContext, 3000, 5000, (jobParams?.jobId ?: 0) + 1)) {
                    Log.d(tag, "Scheduled")
                    PushedService.addLogEvent(this, "Sheduled")
                }
        return false
    }
}
