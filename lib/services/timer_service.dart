import 'dart:async';
import 'package:flutter/material.dart';
import '../data/habit_model.dart';
import '../features/habit/habit_service.dart';

class TimerService {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  final HabitService _habitService = HabitService();
  
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
      return;
    }

    final elapsedSeconds = now.difference(lastUpdate).inSeconds;
    
    if (elapsedSeconds >= habit.intervalSeconds) {
      // 시간 간격이 지났으면 다음 이미지로 변경
      _advanceHabitImage(habit);
      _lastUpdateTimes[habit.id] = now;
    }
  }

  /// 습관 이미지 전진
  Future<void> _advanceHabitImage(Habit habit) async {
    if (habit.imagePaths.isEmpty) return;

    // 다음 이미지 인덱스 계산
    final nextIndex = (habit.currentImageIndex + 1) % habit.imagePaths.length;
    habit.currentImageIndex = nextIndex;

    // 습관 업데이트
    await _habitService.updateHabit(habit);
    
    debugPrint('습관 "${habit.name}" 이미지가 변경되었습니다: ${habit.getCurrentImage()}');
  }

  /// 습관 리셋 시 타이머도 리셋
  void resetHabitTimer(String habitId) {
    _lastUpdateTimes[habitId] = DateTime.now();
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