package com.example.habit_reminder

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import android.content.SharedPreferences
import org.json.JSONObject
import java.io.File

class HabitReminderWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
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
        
        if (widgetDataString != null) {
            try {
                val widgetData = JSONObject(widgetDataString)
                val habitId = widgetData.getString("habit_id")
                val habitName = widgetData.getString("habit_name")
                val imagePath = widgetData.getString("image_path")
                val totalClicks = widgetData.getInt("total_clicks")
                val streakCount = widgetData.getInt("streak_count")
                val imageKey = widgetData.optString("image_key", "") // 캐시 방지용 키
                
                // 이미지 설정 (캐시 방지)
                if (imagePath.isNotEmpty()) {
                    android.util.Log.d("HabitReminderWidget", "이미지 경로: $imagePath")
                    val imageFile = File(imagePath)
                    if (imageFile.exists()) {
                        android.util.Log.d("HabitReminderWidget", "이미지 파일 존재: ${imageFile.absolutePath}")
                        
                        // 이미지 캐시 방지를 위해 새로운 비트맵 생성
                        val options = BitmapFactory.Options().apply {
                            inPurgeable = true
                            inInputShareable = true
                        }
                        
                        val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath, options)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_image, bitmap)
                            android.util.Log.d("HabitReminderWidget", "이미지 설정 완료 (캐시 방지)")
                        } else {
                            android.util.Log.e("HabitReminderWidget", "비트맵 디코딩 실패")
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
                    action = "WIDGET_CLICK_RESET"
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
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        android.util.Log.d("HabitReminderWidget", "onReceive 호출됨: ${intent.action}")
        
        when (intent.action) {
            "WIDGET_CLICK_RESET" -> {
                android.util.Log.d("HabitReminderWidget", "위젯 클릭 이벤트 처리 시작")
                val habitId = intent.getStringExtra("habit_id")
                android.util.Log.d("HabitReminderWidget", "습관 ID: $habitId")
                if (habitId != null) {
                    // 습관 리셋 처리
                    handleHabitReset(context, habitId)
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
            
            // SharedPreferences에 리셋 이벤트 저장
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val resetEvent = JSONObject().apply {
                put("action", "reset_habit")
                put("habit_id", habitId)
                put("timestamp", System.currentTimeMillis())
            }
            
            prefs.edit()
                .putString("flutter.widget_reset_event", resetEvent.toString())
                .apply()
            
            android.util.Log.d("HabitReminderWidget", "리셋 이벤트 저장 완료: $habitId")
            
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
} 