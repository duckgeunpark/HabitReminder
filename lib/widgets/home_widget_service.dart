import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/habit_model.dart';
import '../constants/app_constants.dart';

class HomeWidgetService {
  static const String _widgetDataKey = 'widget_habit_data';
  
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  /// 위젯 초기화
  Future<void> initialize() async {
    try {
      debugPrint('위젯 서비스 초기화 중...');
      await _updateWidgetData();
      debugPrint('위젯 서비스 초기화 완료');
    } catch (e) {
      debugPrint('위젯 초기화 오류: $e');
    }
  }

  /// 활성 습관이 있는지 확인
  Future<bool> hasActiveHabits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habitDataString = prefs.getString(AppConstants.habitDataKey);
      
      if (habitDataString != null) {
        final habitData = jsonDecode(habitDataString) as List;
        final activeHabits = habitData.where((data) => data['isActive'] == true).toList();
        return activeHabits.isNotEmpty;
      }
    } catch (e) {
      debugPrint('활성 습관 확인 오류: $e');
    }
    return false;
  }

  /// 위젯 데이터 업데이트
  Future<void> _updateWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habitDataString = prefs.getString(AppConstants.habitDataKey);
      
      if (habitDataString != null) {
        final habitData = jsonDecode(habitDataString) as List;
        final activeHabits = habitData.where((data) => data['isActive'] == true).toList();
        
        if (activeHabits.isNotEmpty) {
          // 첫 번째 활성 습관을 위젯에 표시
          final firstActiveHabit = activeHabits.first;
          final habitId = firstActiveHabit['id'] as String;
          final habitName = firstActiveHabit['name'] as String;
          final imagePaths = List<String>.from(firstActiveHabit['imagePaths'] ?? []);
          final totalClicks = firstActiveHabit['totalClicks'] ?? 0;
          final streakCount = firstActiveHabit['streakCount'] ?? 0;
          
          // 현재 이미지 인덱스 가져오기
          final currentImageIndex = firstActiveHabit['currentImageIndex'] ?? 0;
          final currentImagePath = imagePaths.isNotEmpty 
              ? imagePaths[currentImageIndex % imagePaths.length]
              : '';
          
          final widgetData = {
            'habit_id': habitId,
            'habit_name': habitName,
            'image_path': currentImagePath,
            'total_clicks': totalClicks,
            'streak_count': streakCount,
            'updated_at': DateTime.now().toIso8601String(),
          };
          
          await prefs.setString(_widgetDataKey, jsonEncode(widgetData));
          debugPrint('위젯 데이터 업데이트 완료: $habitName');
        } else {
          // 활성 습관이 없을 때 기본 데이터 설정
          final widgetData = {
            'habit_id': '',
            'habit_name': '습관 리마인더',
            'image_path': '',
            'total_clicks': 0,
            'streak_count': 0,
            'updated_at': DateTime.now().toIso8601String(),
          };
          
          await prefs.setString(_widgetDataKey, jsonEncode(widgetData));
          debugPrint('활성 습관이 없어 기본 위젯 데이터 설정');
        }
      }
    } catch (e) {
      debugPrint('위젯 데이터 업데이트 오류: $e');
    }
  }

  /// 위젯 업데이트
  Future<void> updateWidget() async {
    try {
      await _updateWidgetData();
      debugPrint('위젯 업데이트 완료');
    } catch (e) {
      debugPrint('위젯 업데이트 오류: $e');
    }
  }

  /// 습관 변경 시 위젯 업데이트
  Future<void> onHabitChanged(String habitId) async {
    try {
      await _updateWidgetData();
      debugPrint('습관 변경으로 인한 위젯 업데이트 완료: $habitId');
    } catch (e) {
      debugPrint('위젯 변경 처리 오류: $e');
    }
  }

  /// 앱 시작 시 위젯 상태 확인
  Future<void> checkWidgetStatus() async {
    try {
      await _updateWidgetData();
      debugPrint('위젯 상태 확인 완료');
    } catch (e) {
      debugPrint('위젯 상태 확인 오류: $e');
    }
  }

  /// 위젯 데이터 가져오기 (위젯에서 사용)
  static Future<Map<String, dynamic>?> getWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final widgetDataString = prefs.getString(_widgetDataKey);
      
      if (widgetDataString != null) {
        return jsonDecode(widgetDataString);
      }
    } catch (e) {
      debugPrint('위젯 데이터 가져오기 오류: $e');
    }
    return null;
  }
}

// 전역 네비게이터 키 (위젯 클릭 시 스낵바 표시용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); 