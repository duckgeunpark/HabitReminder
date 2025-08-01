import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/habit_model.dart';
import '../features/habit/habit_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HomeWidgetService {
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  static const String _widgetDataKey = 'flutter.widget_habit_data';
  static const String _selectedHabitKey = 'flutter.selected_habit_id';
  
  final HabitService _habitService = HabitService();

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
      final prefs = await SharedPreferences.getInstance();
      
      if (activeHabits.isNotEmpty) {
        // 현재 선택된 습관이 활성 습관 목록에 있는지 확인
        final currentSelectedId = prefs.getString(_selectedHabitKey);
        final isCurrentHabitActive = currentSelectedId != null && 
            activeHabits.any((habit) => habit.id == currentSelectedId);
        
        if (isCurrentHabitActive) {
          // 현재 선택된 습관이 여전히 활성 상태면 그대로 유지
          final currentHabit = activeHabits.firstWhere((habit) => habit.id == currentSelectedId);
          await _updateWidgetData(currentHabit);
          debugPrint('현재 선택된 습관 유지: ${currentHabit.name}');
        } else {
          // 현재 선택된 습관이 비활성화되었거나 없는 경우
          if (activeHabits.length == 1) {
            // 활성 습관이 하나뿐인 경우 자동 선택
            final selectedHabit = activeHabits.first;
            await _saveSelectedHabit(selectedHabit.id);
            await _updateWidgetData(selectedHabit);
            debugPrint('활성 습관 자동 선택: ${selectedHabit.name}');
          } else {
            // 활성 습관이 여러 개인 경우 사용자에게 선택하도록 안내
            await _requestHabitSelection();
            // 임시로 첫 번째 습관 표시 (사용자가 선택할 때까지)
            await _clearWidgetData();
            debugPrint('여러 활성 습관 존재 - 사용자 선택 필요');
          }
        }
      } else {
        debugPrint('활성 습관이 없음');
        await prefs.remove(_selectedHabitKey); // 선택된 습관 정보 제거
        await _clearWidgetData();
      }
    } catch (e) {
      debugPrint('활성 습관 선택 오류: $e');
    }
  }
  
  Future<void> _requestHabitSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('widget_setup_requested', true);
      debugPrint('위젯 설정 페이지 요청됨 - 사용자가 습관을 선택해야 함');
    } catch (e) {
      debugPrint('습관 선택 요청 오류: $e');
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
      
      // 빈 상태 표시를 위한 기본 데이터 설정
      final emptyWidgetData = {
        'habit_id': '',
        'habit_name': '활성 습관 없음',
        'image_path': '',
        'total_clicks': 0,
        'streak_count': 0,
        'updated_at': DateTime.now().toIso8601String(),
        'image_key': 'empty_${DateTime.now().millisecondsSinceEpoch}',
        'is_empty': true,
      };
      
      await prefs.setString(_widgetDataKey, jsonEncode(emptyWidgetData));
      debugPrint('위젯 데이터 초기화 완료 - 빈 상태 표시');
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
        if (habit != null && habit.isActive) {
          await _updateWidgetData(habit);
          debugPrint('선택된 습관 변경 감지: ${habit.name}');
        } else {
          // 선택된 습관이 비활성화되었거나 삭제된 경우
          debugPrint('선택된 습관이 비활성화됨 또는 삭제됨: $habitId');
          await checkWidgetStatus(); // 다른 활성 습관으로 자동 전환
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
      if (habit == null) return;
      
      final widgetData = _buildWidgetData(habit, forceUpdate: true);
      final prefs = await SharedPreferences.getInstance();
      
      // 즉시 업데이트를 위한 다중 신호 전송
      await Future.wait([
        _saveWidgetData(prefs, widgetData),
        _setUpdateSignals(prefs),
        _sendWidgetUpdateNotification(habit),
        _sendImmediateUpdateTrigger(prefs),
      ]);
      
      debugPrint('🔄 위젯 즉시 업데이트 트리거: ${habit.name}');
      debugPrint('📷 현재 이미지: ${habit.getCurrentImage()}');
    } catch (e) {
      debugPrint('위젯 이미지 변경 업데이트 오류: $e');
    }
  }
  
  /// 즉시 업데이트를 위한 추가 트리거
  Future<void> _sendImmediateUpdateTrigger(SharedPreferences prefs) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await Future.wait([
      prefs.setString('widget_immediate_update', timestamp.toString()),
      prefs.setBool('widget_force_refresh_now', true),
      prefs.setInt('widget_update_trigger_count', (prefs.getInt('widget_update_trigger_count') ?? 0) + 1),
      // 위젯에 즉시 업데이트 명령 전송
      prefs.setString('widget_instant_command', 'UPDATE_IMAGE_NOW'),
      prefs.setString('widget_last_image_change', timestamp.toString()),
    ]);
    
    debugPrint('⚡ 위젯에 즉시 업데이트 명령 전송 (타임스탬프: $timestamp)');
  }

  Map<String, dynamic> _buildWidgetData(Habit habit, {bool forceUpdate = false}) {
    final now = DateTime.now();
    return {
      'habit_id': habit.id,
      'habit_name': habit.name,
      'image_path': habit.getCurrentImage() ?? '',
      'total_clicks': habit.totalClicks,
      'streak_count': habit.streakCount,
      'updated_at': now.toIso8601String(),
      'image_key': '${habit.id}_${habit.currentImageIndex}_${now.millisecondsSinceEpoch}',
      if (forceUpdate) 'force_update': true,
    };
  }

  Future<void> _saveWidgetData(SharedPreferences prefs, Map<String, dynamic> widgetData) async {
    await prefs.setString(_widgetDataKey, jsonEncode(widgetData));
  }

  Future<void> _setUpdateSignals(SharedPreferences prefs) async {
    final now = DateTime.now().toIso8601String();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    await Future.wait([
      prefs.setString('widget_force_update_signal', now),
      prefs.setString('widget_image_changed', now),
      prefs.setString('widget_refresh_needed', 'true'),
      prefs.setString('widget_image_update_trigger', timestamp.toString()),
      prefs.setBool('widget_needs_immediate_refresh', true),
      _incrementUpdateCounter(prefs),
    ]);
  }

  Future<void> _incrementUpdateCounter(SharedPreferences prefs) async {
    final updateCount = prefs.getInt('widget_update_count') ?? 0;
    await prefs.setInt('widget_update_count', updateCount + 1);
  }

  Future<void> _sendWidgetUpdateNotification(Habit habit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final notificationData = {
        'action': 'image_changed',
        'habit_id': habit.id,
        'habit_name': habit.name,
        'image_path': habit.getCurrentImage() ?? '',
        'current_image_index': habit.currentImageIndex,
        'timestamp': now,
      };
      
      // 여러 방식으로 위젯에 알림
      await Future.wait([
        prefs.setString('widget_direct_notification', jsonEncode(notificationData)),
        prefs.setString('widget_last_update', now),
        prefs.setString('widget_image_change_signal_$timestamp', jsonEncode(notificationData)),
        prefs.setBool('widget_has_pending_update', true),
      ]);
      
      debugPrint('Android 위젯에 다중 알림 전송: ${habit.name}');
      debugPrint('이미지 경로: ${habit.getCurrentImage()}');
      debugPrint('이미지 인덱스: ${habit.currentImageIndex}');
    } catch (e) {
      debugPrint('위젯 알림 전송 오류: $e');
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