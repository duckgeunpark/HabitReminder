import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/habit/habit_service.dart';
import '../data/habit_model.dart';

// 전역 네비게이터 키 (위젯 클릭 시 스낵바 표시용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HomeWidgetService {
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  final HabitService _habitService = HabitService();
  final String _widgetDataKey = 'widget_habit_data';
  final String _selectedHabitKey = 'selected_habit_id';

  Future<void> initialize() async {
    debugPrint('HomeWidgetService 초기화');
  }

  Future<void> checkWidgetStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedHabitId = prefs.getString(_selectedHabitKey);
      
      if (selectedHabitId != null) {
        final habit = _habitService.getHabitById(selectedHabitId);
        if (habit != null && habit.isActive) {
          await _updateWidgetData(habit);
          debugPrint('위젯 상태 확인 완료: ${habit.name}');
        } else {
          debugPrint('선택된 습관이 비활성화되었거나 존재하지 않음');
          await _selectActiveHabit();
        }
      } else {
        debugPrint('선택된 습관이 없음');
        await _selectActiveHabit();
      }
    } catch (e) {
      debugPrint('위젯 상태 확인 오류: $e');
    }
  }

  Future<void> _selectActiveHabit() async {
    try {
      final activeHabits = _habitService.getActiveHabits();
      if (activeHabits.isNotEmpty) {
        final selectedHabit = activeHabits.first;
        await _saveSelectedHabit(selectedHabit.id);
        await _updateWidgetData(selectedHabit);
        debugPrint('활성 습관 자동 선택: ${selectedHabit.name}');
      } else {
        debugPrint('활성 습관이 없음');
        await _clearWidgetData();
      }
    } catch (e) {
      debugPrint('활성 습관 선택 오류: $e');
    }
  }

  Future<void> _updateWidgetData(Habit habit) async {
    try {
      final currentImage = habit.getCurrentImage();
      debugPrint('위젯 데이터 업데이트: ${habit.name} - ${currentImage}');
      
      final widgetData = {
        'habit_id': habit.id,
        'habit_name': habit.name,
        'image_path': currentImage ?? '',
        'total_clicks': habit.totalClicks,
        'streak_count': habit.streakCount,
        'updated_at': DateTime.now().toIso8601String(),
        'image_key': '${habit.id}_${habit.currentImageIndex}_${DateTime.now().millisecondsSinceEpoch}', // 이미지 캐시 방지용 키
      };
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_widgetDataKey, jsonEncode(widgetData));
      debugPrint('위젯 데이터 업데이트 완료: ${habit.name}');
    } catch (e) {
      debugPrint('위젯 데이터 업데이트 오류: $e');
    }
  }

  Future<void> _clearWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_widgetDataKey);
      debugPrint('위젯 데이터 초기화 완료');
    } catch (e) {
      debugPrint('위젯 데이터 초기화 오류: $e');
    }
  }

  Future<void> updateWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedHabitId = prefs.getString(_selectedHabitKey);
      
      if (selectedHabitId != null) {
        final habit = _habitService.getHabitById(selectedHabitId);
        if (habit != null) {
          await _updateWidgetData(habit);
          debugPrint('위젯 업데이트 완료: ${habit.name}');
        }
      }
    } catch (e) {
      debugPrint('위젯 업데이트 오류: $e');
    }
  }

  Future<void> onHabitChanged(String habitId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedHabitId = prefs.getString(_selectedHabitKey);
      
      if (selectedHabitId == habitId) {
        final habit = _habitService.getHabitById(habitId);
        if (habit != null) {
          await _updateWidgetData(habit);
          debugPrint('선택된 습관 변경 감지: ${habit.name}');
        }
      }
    } catch (e) {
      debugPrint('습관 변경 감지 오류: $e');
    }
  }

  Future<void> onWidgetClicked(String habitId) async {
    try {
      debugPrint('위젯 클릭 처리: $habitId');
      await _habitService.resetHabit(habitId);
      
      // 위젯 데이터 즉시 업데이트
      final habit = _habitService.getHabitById(habitId);
      if (habit != null) {
        await _updateWidgetData(habit);
        debugPrint('위젯 클릭 후 데이터 업데이트 완료: ${habit.name}');
      }
    } catch (e) {
      debugPrint('위젯 클릭 처리 오류: $e');
    }
  }

  Future<void> _saveSelectedHabit(String habitId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedHabitKey, habitId);
      debugPrint('선택된 습관 저장: $habitId');
    } catch (e) {
      debugPrint('선택된 습관 저장 오류: $e');
    }
  }

  Future<List<Habit>> getActiveHabits() async {
    try {
      return _habitService.getActiveHabits();
    } catch (e) {
      debugPrint('활성 습관 조회 오류: $e');
      return [];
    }
  }

  Future<Habit?> getSelectedHabit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedHabitId = prefs.getString(_selectedHabitKey);
      
      if (selectedHabitId != null) {
        return _habitService.getHabitById(selectedHabitId);
      }
      return null;
    } catch (e) {
      debugPrint('선택된 습관 조회 오류: $e');
      return null;
    }
  }

  /// 이미지 변경 시 위젯 즉시 업데이트 (캐시 방지)
  Future<void> updateWidgetOnImageChange(String habitId) async {
    try {
      final habit = _habitService.getHabitById(habitId);
      if (habit != null) {
        final currentImage = habit.getCurrentImage();
        debugPrint('이미지 변경으로 위젯 업데이트: ${habit.name} - ${currentImage}');
        
        final widgetData = {
          'habit_id': habit.id,
          'habit_name': habit.name,
          'image_path': currentImage ?? '',
          'total_clicks': habit.totalClicks,
          'streak_count': habit.streakCount,
          'updated_at': DateTime.now().toIso8601String(),
          'image_key': '${habit.id}_${habit.currentImageIndex}_${DateTime.now().millisecondsSinceEpoch}', // 캐시 방지용 고유 키
        };
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_widgetDataKey, jsonEncode(widgetData));
        debugPrint('위젯 이미지 변경 업데이트 완료: ${habit.name}');
      }
    } catch (e) {
      debugPrint('위젯 이미지 변경 업데이트 오류: $e');
    }
  }

  /// 강제 위젯 업데이트 (디버깅용)
  Future<void> forceUpdateWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedHabitId = prefs.getString(_selectedHabitKey);
      
      if (selectedHabitId != null) {
        final habit = _habitService.getHabitById(selectedHabitId);
        if (habit != null) {
          await _updateWidgetData(habit);
          await prefs.setString('widget_force_update', DateTime.now().toIso8601String());
          debugPrint('위젯 강제 업데이트 완료: ${habit.name}');
        }
      }
    } catch (e) {
      debugPrint('위젯 강제 업데이트 오류: $e');
    }
  }
} 