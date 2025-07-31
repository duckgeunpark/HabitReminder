import 'dart:async';
import 'package:flutter/material.dart';
import '../data/habit_model.dart';
import '../features/habit/habit_service.dart';
import '../widgets/home_widget_service.dart';

class TimerService {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  final HabitService _habitService = HabitService();
  final HomeWidgetService _widgetService = HomeWidgetService();
  
  Timer? _timer;
  Map<String, DateTime> _lastUpdateTimes = {};

  /// 타이머 시작
  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkAndUpdateHabits();
    });
  }

  /// 타이머 중지
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 습관들 확인 및 업데이트
  void _checkAndUpdateHabits() {
    final activeHabits = _habitService.getActiveHabits();
    debugPrint('활성 습관 수: ${activeHabits.length}');
    
    for (final habit in activeHabits) {
      _checkHabitTimer(habit);
    }
  }

  /// 개별 습관 타이머 확인
  void _checkHabitTimer(Habit habit) {
    final now = DateTime.now();
    final lastUpdate = _lastUpdateTimes[habit.id];
    
    if (lastUpdate == null) {
      // 첫 실행 시 현재 시간으로 초기화
      _lastUpdateTimes[habit.id] = now;
      debugPrint('습관 "${habit.name}" 타이머 초기화');
      return;
    }

    final elapsedSeconds = now.difference(lastUpdate).inSeconds;
    debugPrint('습관 "${habit.name}" 경과 시간: ${elapsedSeconds}초 / ${habit.intervalSeconds}초');
    
    // 이미지 변경 로직만 실행 (시간이 초과되어도 계속 증가)
    _advanceHabitImage(habit);
  }

  /// 습관 이미지 전진
  Future<void> _advanceHabitImage(Habit habit) async {
    if (habit.imagePaths.isEmpty) return;

    // 현재 경과 시간 계산
    final now = DateTime.now();
    final lastUpdate = _lastUpdateTimes[habit.id] ?? now;
    final elapsedSeconds = now.difference(lastUpdate).inSeconds;
    
    // 타이밍 설정이 있는지 확인
    if (habit.imageTimingsSeconds.isNotEmpty) {
      // 사용자가 설정한 타이밍에 따라 이미지 변경
      final totalSeconds = habit.intervalSeconds;
      
      // 현재 시간에 해당하는 이미지 찾기
      int? nextImageIndex;
      int? nextTiming = null;
      
      for (final entry in habit.imageTimingsSeconds.entries) {
        if (entry.key >= elapsedSeconds) {
          if (nextTiming == null || entry.key < nextTiming!) {
            nextTiming = entry.key;
            nextImageIndex = entry.value;
          }
        }
      }
      
      // 다음 이미지가 있고, 현재 이미지와 다르면 변경
      if (nextImageIndex != null && nextImageIndex != habit.currentImageIndex) {
        habit.currentImageIndex = nextImageIndex;
        
        // 습관 업데이트
        await _habitService.updateHabit(habit);
        
        // 위젯 업데이트
        await _widgetService.updateWidget();
        
        debugPrint('습관 "${habit.name}" 이미지가 변경되었습니다: ${habit.getCurrentImage()} (${elapsedSeconds}초)');
      }
    } else {
      // 타이밍 설정이 없으면 전체 시간을 균등 분할
      final totalSeconds = habit.intervalSeconds;
      final imageCount = habit.imagePaths.length;
      final secondsPerImage = totalSeconds / imageCount;
      
      // 현재 시간에 해당하는 이미지 인덱스 계산
      final currentImageIndex = (elapsedSeconds / secondsPerImage).floor();
      final actualImageIndex = currentImageIndex % imageCount;
      
      // 이미지 인덱스가 변경되었으면 업데이트
      if (habit.currentImageIndex != actualImageIndex) {
        habit.currentImageIndex = actualImageIndex;
        
        // 습관 업데이트
        await _habitService.updateHabit(habit);
        
        // 위젯 업데이트
        await _widgetService.updateWidget();
        
        debugPrint('습관 "${habit.name}" 이미지가 변경되었습니다: ${habit.getCurrentImage()} (${elapsedSeconds}초)');
      }
    }
  }

  /// 습관 리셋 시 타이머도 리셋
  void resetHabitTimer(String habitId) {
    _lastUpdateTimes[habitId] = DateTime.now();
  }

  /// 정적 메서드로 타이머 리셋 (습관 서비스에서 호출)
  static Future<void> resetTimer(String habitId) async {
    final instance = TimerService();
    instance._lastUpdateTimes[habitId] = DateTime.now();
  }

  /// 습관 삭제 시 타이머 정리
  void removeHabitTimer(String habitId) {
    _lastUpdateTimes.remove(habitId);
  }

  /// 앱 시작 시 타이머 초기화
  void initialize() {
    final activeHabits = _habitService.getActiveHabits();
    final now = DateTime.now();
    
    for (final habit in activeHabits) {
      _lastUpdateTimes[habit.id] = now;
    }
    
    startTimer();
  }

  /// 앱 종료 시 타이머 정리
  void dispose() {
    stopTimer();
    _lastUpdateTimes.clear();
  }

  /// 특정 습관의 남은 시간 계산
  Duration getRemainingTime(Habit habit) {
    final lastUpdate = _lastUpdateTimes[habit.id];
    if (lastUpdate == null) return Duration.zero;

    final now = DateTime.now();
    final elapsed = now.difference(lastUpdate).inSeconds;
    final remaining = habit.intervalSeconds - elapsed;
    
    return Duration(seconds: remaining > 0 ? remaining : 0);
  }

  /// 모든 활성 습관의 타이머 상태 가져오기
  Map<String, Duration> getAllRemainingTimes() {
    final activeHabits = _habitService.getActiveHabits();
    final Map<String, Duration> remainingTimes = {};
    
    for (final habit in activeHabits) {
      remainingTimes[habit.id] = getRemainingTime(habit);
    }
    
    return remainingTimes;
  }
} 