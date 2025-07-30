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
                
                // 이미지 설정
                val imageFile = File(imagePath)
                if (imageFile.exists()) {
                    val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_image, bitmap)
                    }
                }
                
                // 텍스트 설정
                views.setTextViewText(R.id.widget_habit_name, habitName)
                views.setTextViewText(R.id.widget_stats, "클릭: $totalClicks | 연속: ${streakCount}일")
                
                // 클릭 이벤트 설정
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("habit_reminder://widget_click?habit_id=$habitId")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                
            } catch (e: Exception) {
                // 오류 발생 시 기본 텍스트 표시
                views.setTextViewText(R.id.widget_habit_name, "습관 리마인더")
                views.setTextViewText(R.id.widget_stats, "위젯을 클릭하세요")
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
        
        // 위젯 클릭 이벤트 처리
        if (intent.action == "WIDGET_CLICK") {
            val habitId = intent.getStringExtra("habit_id")
            if (habitId != null) {
                // Flutter 앱으로 클릭 이벤트 전달
                val flutterIntent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("habit_reminder://widget_click?habit_id=$habitId")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(flutterIntent)
            }
        }
    }
} 