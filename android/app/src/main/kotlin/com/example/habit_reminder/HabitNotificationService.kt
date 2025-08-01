package com.example.habit_reminder

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class HabitNotificationService : Service() {
    
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "habit_progress_channel"
        private const val UPDATE_INTERVAL = 60000L // 1분마다 업데이트
    }
    
    private val handler = Handler(Looper.getMainLooper())
    private var updateRunnable: Runnable? = null
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_TRACKING" -> startHabitTracking()
            "STOP_TRACKING" -> stopHabitTracking()
            "RESET_HABIT" -> resetHabit()
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "습관 진행 상황",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "습관의 실시간 진행 상황을 표시합니다"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun startHabitTracking() {
        updateRunnable = object : Runnable {
            override fun run() {
                updateNotification()
                handler.postDelayed(this, UPDATE_INTERVAL)
            }
        }
        
        // 즉시 알림 표시
        updateNotification()
        
        // 정기 업데이트 시작
        updateRunnable?.let { handler.post(it) }
    }
    
    private fun stopHabitTracking() {
        updateRunnable?.let { handler.removeCallbacks(it) }
        stopForeground(true)
        stopSelf()
    }
    
    private fun resetHabit() {
        // Flutter 앱에 리셋 이벤트 전송
        val resetEvent = JSONObject().apply {
            put("action", "reset_habit_from_notification")
            put("timestamp", System.currentTimeMillis())
        }
        
        val eventFile = filesDir.resolve("notification_reset_event.json")
        eventFile.writeText(resetEvent.toString())
        
        // 즉시 알림 업데이트
        updateNotification()
    }
    
    private fun updateNotification() {
        val habitData = getHabitDataFromPrefs()
        
        if (habitData != null) {
            val notification = createHabitNotification(habitData)
            startForeground(NOTIFICATION_ID, notification)
        }
    }
    
    private fun getHabitDataFromPrefs(): JSONObject? {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val dataString = prefs.getString("flutter.widget_habit_data", null)
            if (dataString != null) JSONObject(dataString) else null
        } catch (e: Exception) {
            null
        }
    }
    
    private fun createHabitNotification(habitData: JSONObject): Notification {
        val habitName = habitData.optString("habit_name", "습관")
        val totalClicks = habitData.optInt("total_clicks", 0)
        val streakCount = habitData.optInt("streak_count", 0)
        
        // 리셋 액션
        val resetIntent = Intent(this, HabitNotificationService::class.java).apply {
            action = "RESET_HABIT"
        }
        val resetPendingIntent = PendingIntent.getService(
            this, 0, resetIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // 앱 열기 액션
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 1, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("$habitName 진행중")
            .setContentText("클릭: ${totalClicks}회 | 연속: ${streakCount}일")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setContentIntent(openAppPendingIntent)
            .addAction(
                R.drawable.ic_refresh, 
                "리셋", 
                resetPendingIntent
            )
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("현재 진행 중인 습관입니다.\n클릭: ${totalClicks}회\n연속: ${streakCount}일\n\n버튼을 눌러 리셋하거나 알림을 터치해서 앱을 열어보세요."))
            .build()
    }
}