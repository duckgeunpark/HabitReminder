import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/habit_model.dart';
import '../../constants/app_constants.dart';
import '../../services/timer_service.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint

class HabitService {
  static final HabitService _instance = HabitService._internal();
  factory HabitService() => _instance;
  HabitService._internal();

  late Box<Habit> _habitBox;

  Future<void> initialize() async {
    _habitBox = await Hive.openBox<Habit>(AppConstants.habitBoxName);
  }

  List<Habit> getAllHabits() {
    return _habitBox.values.toList();
  }

  List<Habit> getActiveHabits() {
    return _habitBox.values.where((habit) => habit.isActive).toList();
  }

  Habit? getHabitById(String id) {
    try {
      return _habitBox.values.firstWhere((habit) => habit.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addHabit(Habit habit) async {
    await _habitBox.add(habit);
    await _saveToSharedPreferences();
    await _notifyWidgetUpdate();
  }

  Future<void> updateHabit(Habit habit) async {
    final index = _habitBox.values.toList().indexWhere((h) => h.id == habit.id);
    if (index != -1) {
      await _habitBox.putAt(index, habit);
      await _saveToSharedPreferences();
      await _notifyWidgetUpdate();
    }
  }

  Future<void> deleteHabit(String id) async {
    final habit = getHabitById(id);
    if (habit != null) {
      await _habitBox.deleteAt(_habitBox.values.toList().indexWhere((h) => h.id == id));
      await _saveToSharedPreferences();
      await _notifyWidgetUpdate();
    }
  }

  Future<void> toggleHabitActive(String id) async {
    final habit = getHabitById(id);
    if (habit != null) {
      final now = DateTime.now();
      
      if (habit.isActive) {
        // 활성화 → 비활성화: 활성화된 시간을 총 시간에 추가
        if (habit.activatedTime != null) {
          final activeDuration = now.difference(habit.activatedTime!);
          habit.totalActiveSeconds += activeDuration.inSeconds;
          habit.activatedTime = null;
          debugPrint('습관 "${habit.name}" 비활성화: 총 활성화 시간 ${habit.totalActiveSeconds}초');
        }
      } else {
        // 비활성화 → 활성화: 활성화 시작 시간 기록
        habit.activatedTime = now;
        debugPrint('습관 "${habit.name}" 활성화 시작');
      }
      
      habit.isActive = !habit.isActive;
      await updateHabit(habit);
    }
  }

  Future<void> resetHabit(String id) async {
    final habit = getHabitById(id);
    if (habit != null) {
      // 현재 이미지 인덱스를 클릭한 이미지로 저장
      habit.clickedImageIndex = habit.currentImageIndex;
      habit.currentImageIndex = 0;
      habit.totalClicks++;
      
      // 클릭 시간 기록
      final now = DateTime.now();
      final lastUpdate = habit.lastResetTime ?? habit.createdAt;
      final clickTime = now.difference(lastUpdate).inSeconds;
      
      habit.clickTimes.add(clickTime);
      habit.clickTimestamps.add(now);
      
      debugPrint('습관 "${habit.name}" 클릭 시간 기록: ${clickTime}초');
      
      // 연속일 계산 로직 수정
      if (habit.lastResetTime != null) {
        final timeDifference = now.difference(habit.lastResetTime!);
        // 24시간이 지났는지 확인
        if (timeDifference.inHours >= 24) {
          habit.streakCount++;
        }
      } else {
        // 첫 번째 클릭인 경우
        habit.streakCount = 1;
      }
      
      habit.lastResetTime = now;
      await updateHabit(habit);
      TimerService().resetHabitTimer(habit.id);
      
      // 위젯 업데이트 알림 (SharedPreferences를 통해)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('widget_reset_habit_id', habit.id);
        await prefs.setString('widget_update_timestamp', DateTime.now().toIso8601String());
        debugPrint('습관 리셋 후 위젯 업데이트 알림 전송: ${habit.name}');
      } catch (e) {
        debugPrint('습관 리셋 후 위젯 업데이트 알림 오류: $e');
      }
    }
  }

  Future<void> nextHabitImage(String id) async {
    final habit = getHabitById(id);
    if (habit != null && habit.imagePaths.isNotEmpty) {
      habit.currentImageIndex = (habit.currentImageIndex + 1) % habit.imagePaths.length;
      await updateHabit(habit);
    }
  }

  Map<String, dynamic> getStatistics() {
    final habits = getAllHabits();
    final activeHabits = getActiveHabits();
    
    return {
      'total_habits': habits.length,
      'active_habits': activeHabits.length,
      'total_clicks': habits.fold(0, (sum, habit) => sum + habit.totalClicks),
      'total_streaks': habits.fold(0, (sum, habit) => sum + habit.streakCount),
    };
  }

  Future<void> _saveToSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habits = getAllHabits();
      final habitData = habits.map((habit) => habit.toJson()).toList();
      await prefs.setString(AppConstants.habitDataKey, jsonEncode(habitData));
    } catch (e) {
      print('SharedPreferences 저장 오류: $e');
    }
  }

  Future<void> _notifyWidgetUpdate() async {
    try {
      // HomeWidgetService를 직접 참조하지 않고 SharedPreferences를 통해 통신
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_update_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('위젯 업데이트 알림 오류: $e');
    }
  }

  Future<void> loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habitDataString = prefs.getString(AppConstants.habitDataKey);
      
      if (habitDataString != null) {
        final habitData = jsonDecode(habitDataString) as List;
        for (final data in habitData) {
          final habit = Habit.fromJson(data);
          await _habitBox.add(habit);
        }
      }
    } catch (e) {
      print('SharedPreferences 로드 오류: $e');
    }
  }

  Future<void> clearAllData() async {
    await _habitBox.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.habitDataKey);
  }

  Future<String> createBackup() async {
    try {
      final habits = getAllHabits();
      final backupData = {
        'version': '1.0',
        'created_at': DateTime.now().toIso8601String(),
        'habits': habits.map((habit) => habit.toJson()).toList(),
      };
      return jsonEncode(backupData);
    } catch (e) {
      throw Exception('백업 생성 실패: $e');
    }
  }

  Future<void> restoreFromBackup(String backupData) async {
    try {
      final data = jsonDecode(backupData);
      final habitsData = data['habits'] as List;
      
      await _habitBox.clear();
      
      for (final habitData in habitsData) {
        final habit = Habit.fromJson(habitData);
        await _habitBox.add(habit);
      }
      
      await _saveToSharedPreferences();
    } catch (e) {
      throw Exception('백업 복원 실패: $e');
    }
  }

  Future<void> createSampleData() async {
    final sampleHabits = [
      Habit(
        id: 'sample_1',
        name: '웃는 습관',
        imagePaths: ['assets/images/sample_smile_1.jpg', 'assets/images/sample_smile_2.jpg'],
        intervalSeconds: 30,
        createdAt: DateTime.now(),
        isActive: true,
        currentImageIndex: 0,
        lastResetTime: null,
        streakCount: 0,
        totalClicks: 0,
      ),
      Habit(
        id: 'sample_2',
        name: '물 마시기',
        imagePaths: ['assets/images/sample_water_1.jpg', 'assets/images/sample_water_2.jpg'],
        intervalSeconds: 1800, // 30분
        createdAt: DateTime.now(),
        isActive: false,
        currentImageIndex: 0,
        lastResetTime: null,
        streakCount: 0,
        totalClicks: 0,
      ),
    ];

    for (final habit in sampleHabits) {
      await addHabit(habit);
    }
  }
} 