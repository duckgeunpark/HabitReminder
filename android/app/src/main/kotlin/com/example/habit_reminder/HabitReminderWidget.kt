package com.example.habit_reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

class HabitReminderWidget : AppWidgetProvider() {

    companion object {
        private const val WIDGET_UPDATE_ACTION = "WIDGET_AUTO_UPDATE"
        private const val WIDGET_CLICK_RESET = "WIDGET_CLICK_RESET"
        private const val WIDGET_LONG_CLICK_SETTINGS = "WIDGET_LONG_CLICK_SETTINGS"
        private const val WIDGET_UPDATE_INTERVAL = 1800000L // 30분마다 업데이트 (시스템 최소값)
        private const val TAG = "HabitReminderWidget"
        
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val WIDGET_DATA_KEY = "flutter.widget_habit_data"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
        
        // 자동 업데이트 설정
        scheduleWidgetUpdate(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // 위젯이 처음 추가될 때 습관 선택 화면 열기
        openHabitSelectionActivity(context)
        // 자동 업데이트 시작
        scheduleWidgetUpdate(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // 위젯이 제거될 때 자동 업데이트 중지
        cancelWidgetUpdate(context)
    }

    private fun scheduleWidgetUpdate(context: Context) {
        // Android 정책상 30분 미만 자동 업데이트는 불가능
        // 대신 앱이 활성화될 때와 사용자 상호작용 시에만 업데이트
        android.util.Log.d("HabitReminderWidget", "위젯은 사용자 상호작용과 앱 활성화 시에만 업데이트됩니다")
    }

    private fun cancelWidgetUpdate(context: Context) {
        // 자동 업데이트를 사용하지 않으므로 취소할 것이 없음
        android.util.Log.d("HabitReminderWidget", "위젯 업데이트 스케줄 해제")
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.habit_reminder_widget)
        
        // SharedPreferences에서 위젯 데이터 가져오기
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val widgetDataString = prefs.getString("flutter.widget_habit_data", null)
        val forceUpdateSignal = prefs.getString("widget_force_update_signal", null)
        val imageChangedSignal = prefs.getString("widget_image_changed", null)
        val refreshNeeded = prefs.getString("widget_refresh_needed", null)
        val imageUpdateTrigger = prefs.getString("widget_image_update_trigger", null)
        val needsImmediateRefresh = prefs.getBoolean("widget_needs_immediate_refresh", false)
        val hasPendingUpdate = prefs.getBoolean("widget_has_pending_update", false)
        val immediateUpdate = prefs.getString("widget_immediate_update", null)
        val forceRefreshNow = prefs.getBoolean("widget_force_refresh_now", false)
        val instantCommand = prefs.getString("widget_instant_command", null)
        val lastImageChange = prefs.getString("widget_last_image_change", null)
        val updateTriggerCount = prefs.getInt("widget_update_trigger_count", 0)
        val updateCount = prefs.getInt("widget_update_count", 0)
        val directNotification = prefs.getString("widget_direct_notification", null)
        val lastUpdate = prefs.getString("widget_last_update", null)
        
        // 타임스탬프 기반 신호들도 확인
        val allKeys = prefs.all.keys
        val imageChangeSignals = allKeys.filter { it.startsWith("widget_image_change_signal_") }
        
        // 신호 상태를 한 줄로 요약
        val hasAnySignal = forceUpdateSignal != null || imageChangedSignal != null || 
                          refreshNeeded != null || immediateUpdate != null || forceRefreshNow ||
                          hasPendingUpdate || instantCommand != null || imageChangeSignals.isNotEmpty()
        
        android.util.Log.d(TAG, "🎯 위젯 업데이트 | 신호감지: $hasAnySignal | 즉시명령: ${instantCommand != null} | 트리거: $updateTriggerCount")
        
        // 즉시 명령이 있으면 우선 처리
        if (instantCommand == "UPDATE_IMAGE_NOW") {
            android.util.Log.d(TAG, "⚡ 즉시 이미지 업데이트 명령 수신! 타임스탬프: $lastImageChange")
            // 명령 처리 후 즉시 삭제
            prefs.edit().remove("widget_instant_command").remove("widget_last_image_change").apply()
        }
        
        // 타임스탬프 기반 신호들 처리
        if (imageChangeSignals.isNotEmpty()) {
            android.util.Log.d("HabitReminderWidget", "타임스탬프 기반 이미지 변경 신호 감지됨")
            // 가장 최근 신호 사용
            val latestSignalKey = imageChangeSignals.maxByOrNull { 
                it.substringAfter("widget_image_change_signal_").toLongOrNull() ?: 0L 
            }
            
            if (latestSignalKey != null) {
                val signalData = prefs.getString(latestSignalKey, null)
                android.util.Log.d("HabitReminderWidget", "최신 신호 데이터: $signalData")
                
                // 신호 처리 후 삭제
                prefs.edit().remove(latestSignalKey).apply()
            }
        }
        
        // 직접 알림이 있으면 즉시 처리
        if (directNotification != null) {
            try {
                val notificationData = JSONObject(directNotification)
                val notificationAction = notificationData.getString("action")
                val directHabitId = notificationData.getString("habit_id")
                val directHabitName = notificationData.getString("habit_name")
                val directImagePath = notificationData.getString("image_path")
                val currentImageIndex = notificationData.getInt("current_image_index")
                
                android.util.Log.d("HabitReminderWidget", "직접 알림 처리: $notificationAction - $directHabitName (이미지 인덱스: $currentImageIndex)")
                
                // 이미지 설정
                if (directImagePath.isNotEmpty()) {
                    val imageFile = File(directImagePath)
                    if (imageFile.exists()) {
                        val options = BitmapFactory.Options().apply {
                            inPurgeable = true
                            inInputShareable = true
                            inMutable = true
                        }
                        
                        val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath, options)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_image, bitmap)
                            android.util.Log.d("HabitReminderWidget", "직접 알림으로 이미지 업데이트 완료: $directHabitName")
                        }
                    }
                }
                
                // 텍스트 설정
                views.setTextViewText(R.id.widget_habit_name, directHabitName)
                views.setTextViewText(R.id.widget_stats, "이미지 변경됨")
                
                // 위젯 클릭 이벤트 설정
                val directResetIntent = Intent(context, HabitReminderWidget::class.java).apply {
                    action = WIDGET_CLICK_RESET
                    putExtra("habit_id", directHabitId)
                }
                
                val directResetPendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    directResetIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                views.setOnClickPendingIntent(R.id.widget_container, directResetPendingIntent)
                
                // 직접 알림 삭제
                prefs.edit().remove("widget_direct_notification").apply()
                android.util.Log.d("HabitReminderWidget", "직접 알림 처리 완료 및 삭제")
                
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
                
            } catch (e: Exception) {
                android.util.Log.e("HabitReminderWidget", "직접 알림 처리 오류: $e")
            }
        }
        
        if (widgetDataString != null) {
            try {
                val widgetData = JSONObject(widgetDataString)
                val habitId = widgetData.getString("habit_id")
                val habitName = widgetData.getString("habit_name")
                val imagePath = widgetData.getString("image_path")
                val totalClicks = widgetData.getInt("total_clicks")
                val streakCount = widgetData.getInt("streak_count")
                val imageKey = widgetData.optString("image_key", "") // 캐시 방지용 키
                val forceUpdate = widgetData.optBoolean("force_update", false)
                val isEmpty = widgetData.optBoolean("is_empty", false)
                
                android.util.Log.d("HabitReminderWidget", "위젯 데이터 파싱 완료 - 강제 업데이트: $forceUpdate, 빈 상태: $isEmpty")
                android.util.Log.d("HabitReminderWidget", "현재 이미지 경로: $imagePath")
                
                // 빈 상태 처리
                if (isEmpty) {
                    // 활성 습관이 없는 경우
                    views.setTextViewText(R.id.widget_habit_name, habitName)
                    views.setTextViewText(R.id.widget_stats, "앱에서 습관을 활성화하세요")
                    views.setImageViewResource(R.id.widget_image, android.R.drawable.ic_dialog_alert)
                    
                    // 클릭 시 앱 열기
                    val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    val openAppPendingIntent = PendingIntent.getActivity(
                        context, 0, openAppIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)
                    
                    android.util.Log.d("HabitReminderWidget", "빈 상태 위젯 설정 완료")
                } else {
                    // 일반 습관 데이터 처리
                    // 이미지 설정 (캐시 방지 강화)
                    if (imagePath.isNotEmpty()) {
                    android.util.Log.d("HabitReminderWidget", "이미지 경로: $imagePath")
                    val imageFile = File(imagePath)
                    if (imageFile.exists()) {
                        android.util.Log.d("HabitReminderWidget", "이미지 파일 존재: ${imageFile.absolutePath}")
                        
                        // 이미지 캐시 방지를 위해 새로운 비트맵 생성 (강화된 옵션)
                        val options = BitmapFactory.Options().apply {
                            inPurgeable = true
                            inInputShareable = true
                            inMutable = true // 변경 가능한 비트맵으로 생성
                        }
                        
                        val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath, options)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_image, bitmap)
                            android.util.Log.d(TAG, "✅ 위젯 이미지 업데이트 성공: ${imagePath.substringAfterLast("/")}")
                        } else {
                            android.util.Log.e(TAG, "❌ 비트맵 디코딩 실패: ${imagePath.substringAfterLast("/")}")
                        }
                    } else {
                        android.util.Log.e("HabitReminderWidget", "이미지 파일이 존재하지 않음: ${imageFile.absolutePath}")
                    }
                } else {
                    android.util.Log.e("HabitReminderWidget", "이미지 경로가 비어있음")
                }
                
                // 텍스트 설정
                views.setTextViewText(R.id.widget_habit_name, habitName)
                views.setTextViewText(R.id.widget_stats, "클릭: $totalClicks | 연속: ${streakCount}일")
                
                // 위젯 클릭 시 습관 리셋
                val resetIntent = Intent(context, HabitReminderWidget::class.java).apply {
                    action = WIDGET_CLICK_RESET
                    putExtra("habit_id", habitId)
                }
                
                android.util.Log.d("HabitReminderWidget", "위젯 클릭 이벤트 설정: habitId=$habitId")
                
                val resetPendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    resetIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                    views.setOnClickPendingIntent(R.id.widget_container, resetPendingIntent)
                    android.util.Log.d("HabitReminderWidget", "위젯 클릭 이벤트 설정 완료")
                }
                
                // 강제 업데이트 신호가 있으면 로그 출력 및 신호 삭제
                if (forceUpdate || forceUpdateSignal != null || imageChangedSignal != null || 
                    refreshNeeded != null || imageUpdateTrigger != null || needsImmediateRefresh || 
                    hasPendingUpdate || immediateUpdate != null || forceRefreshNow || 
                    instantCommand != null || imageChangeSignals.isNotEmpty()) {
                    android.util.Log.d("HabitReminderWidget", "강제 업데이트 감지됨 - 이미지 변경")
                    
                    // 모든 신호들을 한 번에 삭제 (효율성 향상)
                    val editor = prefs.edit()
                    
                    if (forceUpdateSignal != null) {
                        android.util.Log.d("HabitReminderWidget", "강제 업데이트 신호로 즉시 새로고침")
                        editor.remove("widget_force_update_signal")
                    }
                    if (imageChangedSignal != null) {
                        android.util.Log.d("HabitReminderWidget", "이미지 변경 신호 감지")
                        editor.remove("widget_image_changed")
                    }
                    if (refreshNeeded != null) {
                        android.util.Log.d("HabitReminderWidget", "새로고침 필요 신호 감지")
                        editor.remove("widget_refresh_needed")
                    }
                    if (imageUpdateTrigger != null) {
                        android.util.Log.d("HabitReminderWidget", "이미지 업데이트 트리거 감지")
                        editor.remove("widget_image_update_trigger")
                    }
                    if (needsImmediateRefresh) {
                        android.util.Log.d("HabitReminderWidget", "즉시 새로고침 신호 감지")
                        editor.remove("widget_needs_immediate_refresh")
                    }
                    if (hasPendingUpdate) {
                        android.util.Log.d("HabitReminderWidget", "대기 중 업데이트 신호 감지")
                        editor.remove("widget_has_pending_update")
                    }
                    if (immediateUpdate != null) {
                        android.util.Log.d("HabitReminderWidget", "⚡ 즉시 업데이트 신호 감지")
                        editor.remove("widget_immediate_update")
                    }
                    if (forceRefreshNow) {
                        android.util.Log.d("HabitReminderWidget", "🔄 강제 새로고침 신호 감지")
                        editor.remove("widget_force_refresh_now")
                    }
                    
                    // 모든 타임스탬프 기반 신호들 삭제
                    imageChangeSignals.forEach { signalKey ->
                        editor.remove(signalKey)
                        android.util.Log.d("HabitReminderWidget", "타임스탬프 신호 삭제: $signalKey")
                    }
                    
                    editor.apply()
                }
                
            } catch (e: Exception) {
                // 오류 발생 시 기본 텍스트 표시
                views.setTextViewText(R.id.widget_habit_name, "습관 리마인더")
                views.setTextViewText(R.id.widget_stats, "위젯을 클릭하세요")
                android.util.Log.e("HabitReminderWidget", "위젯 업데이트 오류: $e")
            }
        } else {
            // 데이터가 없을 때 기본 텍스트 표시
            views.setTextViewText(R.id.widget_habit_name, "습관 리마인더")
            views.setTextViewText(R.id.widget_stats, "활성 습관이 없습니다")
        }
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
        android.util.Log.d("HabitReminderWidget", "위젯 업데이트 완료")
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        android.util.Log.d("HabitReminderWidget", "onReceive 호출됨: ${intent.action}")
        android.util.Log.d("HabitReminderWidget", "Intent 데이터: ${intent.extras}")
        
        when (intent.action) {
            WIDGET_UPDATE_ACTION -> {
                // 자동 업데이트
                android.util.Log.d("HabitReminderWidget", "자동 업데이트 실행")
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, HabitReminderWidget::class.java)
                )
                
                for (appWidgetId in appWidgetIds) {
                    updateWidget(context, appWidgetManager, appWidgetId)
                }
            }
            "WIDGET_CLICK_RESET" -> {
                android.util.Log.d("HabitReminderWidget", "위젯 클릭 이벤트 처리 시작")
                val habitId = intent.getStringExtra("habit_id")
                android.util.Log.d("HabitReminderWidget", "습관 ID: $habitId")
                if (habitId != null) {
                    // 습관 리셋 처리
                    handleHabitReset(context, habitId)
                } else {
                    android.util.Log.e("HabitReminderWidget", "습관 ID가 null입니다")
                }
            }
            "WIDGET_LONG_CLICK_SETTINGS" -> {
                // 설정 페이지로 이동
                val settingsIntent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("habit_reminder://widget_settings")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(settingsIntent)
            }
            else -> {
                android.util.Log.d("HabitReminderWidget", "알 수 없는 액션: ${intent.action}")
            }
        }
    }
    
    private fun handleHabitReset(context: Context, habitId: String) {
        try {
            android.util.Log.d("HabitReminderWidget", "위젯 클릭 처리 시작: habitId=$habitId")
            
            // 즉시 위젯을 "처리 중" 상태로 업데이트
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, HabitReminderWidget::class.java)
            )
            
            if (appWidgetIds.isNotEmpty()) {
                val views = RemoteViews(context.packageName, R.layout.habit_reminder_widget)
                views.setTextViewText(R.id.widget_habit_name, "처리 중...")
                views.setTextViewText(R.id.widget_stats, "습관 리셋 중")
                appWidgetManager.updateAppWidget(appWidgetIds[0], views)
            }
            
            // 파일을 통해 Flutter 앱에 이벤트 전송
            val resetEvent = JSONObject().apply {
                put("action", "reset_habit")
                put("habit_id", habitId)
                put("timestamp", System.currentTimeMillis())
            }
            
            val eventFile = File(context.filesDir, "widget_reset_event.json")
            eventFile.writeText(resetEvent.toString())
            
            android.util.Log.d("HabitReminderWidget", "이벤트 파일 저장 완료: ${eventFile.absolutePath}")
            android.util.Log.d("HabitReminderWidget", "저장된 값: ${resetEvent.toString()}")
            
            // 1초 후 위젯 업데이트
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    updateWidget(context, appWidgetManager, appWidgetIds[0])
                    android.util.Log.d("HabitReminderWidget", "위젯 업데이트 완료")
                } catch (e: Exception) {
                    android.util.Log.e("HabitReminderWidget", "지연된 위젯 업데이트 오류: $e")
                }
            }, 1000)
            
        } catch (e: Exception) {
            android.util.Log.e("HabitReminderWidget", "위젯 클릭 처리 오류: $e")
        }
    }
    
    private fun openHabitSelectionActivity(context: Context) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("habit_reminder://widget_setup")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            android.util.Log.d(TAG, "습관 선택 화면 열기 시도")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "습관 선택 화면 열기 실패: $e")
        }
    }
} 