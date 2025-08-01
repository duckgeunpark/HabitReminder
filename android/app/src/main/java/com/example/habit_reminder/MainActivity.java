package com.example.habit_reminder;

import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.habit_reminder/deep_link";
    private static final String TAG = "MainActivity";
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        handleDeepLink(getIntent());
    }
    
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleDeepLink(intent);
    }
    
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("getInitialDeepLink")) {
                    SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
                    boolean deepLinkFlag = prefs.getBoolean("widget_setup_requested", false);
                    result.success(deepLinkFlag);
                } else {
                    result.notImplemented();
                }
            });
    }
    
    private void handleDeepLink(Intent intent) {
        String action = intent.getAction();
        Uri data = intent.getData();
        
        if (Intent.ACTION_VIEW.equals(action) && data != null) {
            String scheme = data.getScheme();
            String host = data.getHost();
            
            Log.d(TAG, "딥링크 수신: " + scheme + "://" + host);
            
            if ("habit_reminder".equals(scheme) && ("widget_setup".equals(host) || "widget_settings".equals(host))) {
                // SharedPreferences에 플래그 설정
                SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
                prefs.edit().putBoolean("widget_setup_requested", true).apply();
                
                Log.d(TAG, "위젯 설정 요청 플래그 설정됨");
            }
        }
    }
}
