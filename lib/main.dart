import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'constants/app_constants.dart';
import 'data/habit_model.dart';
import 'features/habit/habit_service.dart';
import 'features/habit/add_habit_page.dart';
import 'features/habit/habit_detail_page.dart';
import 'features/habit/edit_habit_page.dart';
import 'features/widget/widget_settings_page.dart';
import 'services/timer_service.dart';
import 'widgets/home_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(HabitAdapter());
  await HabitService().initialize();
  await HomeWidgetService().initialize();
  TimerService().initialize();
  runApp(const HabitReminderApp());
}

class HabitReminderApp extends StatelessWidget {
  const HabitReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: App.getLightTheme(),
      darkTheme: App.getDarkTheme(),
      themeMode: ThemeMode.system,
      navigatorKey: navigatorKey,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final HabitService _habitService;
  late final HomeWidgetService _widgetService;
  late final TimerService _timerService;
  List<Habit> _habits = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupLifecycleObserver();
    _loadInitialData();
  }

  void _initializeServices() {
    _habitService = HabitService();
    _widgetService = HomeWidgetService();
    _timerService = TimerService();
  }

  void _setupLifecycleObserver() {
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWidgetIntent();
    });
  }

  void _loadInitialData() {
    _loadHabits();
    _checkWidgetStatus();
    _startActiveTimeTimer();
    _checkWidgetResetEvent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드에 올 때 위젯 이벤트 확인 및 업데이트
      _checkWidgetResetEvent();
      _widgetService.updateWidget(); // 앱 활성화 시 위젯 업데이트
      debugPrint('앱 활성화로 인한 위젯 업데이트');
    } else if (state == AppLifecycleState.paused) {
      // 앱이 백그라운드로 갈 때 최종 위젯 상태 업데이트
      _widgetService.updateWidget();
      debugPrint('앱 백그라운드 전환으로 인한 위젯 업데이트');
    }
  }

  Future<void> _checkWidgetResetEvent() async {
    try {
      const eventFilePath = '/data/data/com.example.habit_reminder/files/widget_reset_event.json';
      final eventFile = File(eventFilePath);
      
      if (!await eventFile.exists()) return;
      
      final resetEventString = await eventFile.readAsString();
      debugPrint('위젯 이벤트 파일 감지: $resetEventString');
      
      final resetEvent = jsonDecode(resetEventString);
      final habitId = resetEvent['habit_id'] as String;
      debugPrint('위젯 클릭된 습관 ID: $habitId');
      
      final habit = _habitService.getHabitById(habitId);
      if (habit != null) {
        debugPrint('습관 정보 찾음: ${habit.name}');
        await _onHabitImageTap(habit, isFromWidget: true);
        debugPrint('위젯 클릭 처리 완료: ${habit.name}');
      } else {
        debugPrint('습관 정보를 찾을 수 없음: $habitId');
      }
      
      await eventFile.delete();
      debugPrint('위젯 이벤트 파일 삭제 완료');
    } catch (e) {
      debugPrint('위젯 리셋 이벤트 확인 오류: $e');
    }
  }

  void _startActiveTimeTimer() {
    // Android 위젯은 30분 미만 자동 업데이트가 불가능하므로
    // 앱이 활성화된 상태에서만 업데이트
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      _checkAllWidgetEvents();
      _updateActiveHabits();
    });
  }

  void _checkAllWidgetEvents() {
    _checkWidgetResetEvent();
    _checkWidgetUpdateNotification();
    _checkAndRefreshHabits();
  }

  void _updateActiveHabits() {
    final activeHabits = _habitService.getActiveHabits();
    bool hasChanges = false;
    
    for (final habit in activeHabits) {
      if (_updateHabitActiveTime(habit)) hasChanges = true;
      if (_updateHabitImage(habit)) {
        hasChanges = true;
        // 이미지가 변경되면 즉시 위젯에 알림
        _widgetService.updateWidgetOnImageChange(habit.id);
      }
    }
    
    if (hasChanges) {
      _refreshHabitsAndWidget();
    }
  }

  bool _updateHabitActiveTime(Habit habit) {
    if (!habit.isActive || habit.activatedTime == null) return false;
    
    final now = DateTime.now();
    final activeDuration = now.difference(habit.activatedTime!);
    final newTotalActiveSeconds = habit.totalActiveSeconds + activeDuration.inSeconds;
    
    if (habit.totalActiveSeconds != newTotalActiveSeconds) {
      habit.totalActiveSeconds = newTotalActiveSeconds;
      habit.activatedTime = now;
      _habitService.updateHabit(habit);
      debugPrint('습관 "${habit.name}" 활성화 시간 업데이트: ${habit.totalActiveSeconds}초');
      return true;
    }
    return false;
  }

  bool _updateHabitImage(Habit habit) {
    if (habit.imagePaths.isEmpty) return false;
    
    final now = DateTime.now();
    final lastUpdate = habit.lastResetTime ?? habit.createdAt;
    final elapsedSeconds = now.difference(lastUpdate).inSeconds;
    
    final newImageIndex = _calculateImageIndex(habit, elapsedSeconds);
    
    if (newImageIndex != habit.currentImageIndex) {
      final oldImageIndex = habit.currentImageIndex;
      habit.currentImageIndex = newImageIndex;
      _habitService.updateHabit(habit);
      debugPrint('🖼️ 이미지 변경 감지: "${habit.name}" ${oldImageIndex} → ${newImageIndex} (${elapsedSeconds}초)');
      debugPrint('📁 새 이미지 경로: ${habit.getCurrentImage()}');
      
      _widgetService.updateWidgetOnImageChange(habit.id).then((_) {
        debugPrint('✅ 위젯 업데이트 신호 전송 완료: ${habit.name}');
      });
      return true;
    }
    return false;
  }

  int _calculateImageIndex(Habit habit, int elapsedSeconds) {
    if (habit.imageTimingsSeconds.isNotEmpty) {
      return _calculateImageIndexFromTimings(habit, elapsedSeconds);
    } else {
      return _calculateImageIndexUniform(habit, elapsedSeconds);
    }
  }

  int _calculateImageIndexFromTimings(Habit habit, int elapsedSeconds) {
    int? nextImageIndex;
    int? nextTiming;
    
    for (final entry in habit.imageTimingsSeconds.entries) {
      if (entry.key >= elapsedSeconds) {
        if (nextTiming == null || entry.key < nextTiming) {
          nextTiming = entry.key;
          nextImageIndex = entry.value;
        }
      }
    }
    
    return nextImageIndex ?? habit.currentImageIndex;
  }

  int _calculateImageIndexUniform(Habit habit, int elapsedSeconds) {
    final imageCount = habit.imagePaths.length;
    final secondsPerImage = habit.intervalSeconds / imageCount;
    final currentImageIndex = (elapsedSeconds / secondsPerImage).floor();
    return currentImageIndex % imageCount;
  }

  void _refreshHabitsAndWidget() {
    final updatedHabits = _habitService.getAllHabits();
    setState(() {
      _habits = updatedHabits;
    });
    _widgetService.updateWidget();
  }

  Future<void> _checkWidgetUpdateNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resetHabitId = prefs.getString('widget_reset_habit_id');
      final updateTimestamp = prefs.getString('widget_update_timestamp');
      
      if (resetHabitId != null && updateTimestamp != null) {
        // 위젯 업데이트 알림 처리
        await _widgetService.updateWidgetOnImageChange(resetHabitId);
        
        // 알림 데이터 삭제
        await prefs.remove('widget_reset_habit_id');
        await prefs.remove('widget_update_timestamp');
        
        debugPrint('위젯 업데이트 알림 처리 완료: $resetHabitId');
      }
    } catch (e) {
      debugPrint('위젯 업데이트 알림 처리 오류: $e');
    }
  }

  Future<void> _loadHabits() async {
    final habits = _habitService.getAllHabits();
    setState(() {
      _habits = habits;
    });
  }

  Future<void> _checkWidgetStatus() async {
    await _widgetService.checkWidgetStatus();
  }

  Future<void> _onHabitImageTap(Habit habit, {bool isFromWidget = false}) async {
    debugPrint('_onHabitImageTap 호출됨: ${habit.name}, isFromWidget: $isFromWidget');
    
    if (habit.isActive) {
      debugPrint('습관 활성화 상태 확인됨: ${habit.name}');
      try {
        await _habitService.resetHabit(habit.id);
        debugPrint('습관 리셋 완료: ${habit.name}');
        await _loadHabits();
        debugPrint('습관 목록 새로고침 완료');
        await _widgetService.onHabitChanged(habit.id);
        debugPrint('위젯 업데이트 완료: ${habit.name}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFromWidget 
              ? '${habit.name} 습관이 위젯에서 초기화되었습니다!' 
              : '${habit.name} 습관이 초기화되었습니다!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
        debugPrint('SnackBar 표시 완료');
      } catch (e) {
        debugPrint('습관 초기화 중 오류: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('습관 초기화 중 오류가 발생했습니다.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else {
      debugPrint('습관 비활성화 상태: ${habit.name}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${habit.name} 습관을 활성화한 후 클릭해주세요.'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
  }

  Future<void> _toggleHabitActive(Habit habit) async {
    try {
      final wasActive = habit.isActive;
      await _habitService.toggleHabitActive(habit.id);
      await _loadHabits();
      
      // 습관 상태 변경 후 위젯 상태 확인 및 업데이트
      if (wasActive && !habit.isActive) {
        // 활성에서 비활성으로 변경된 경우
        debugPrint('습관 비활성화: ${habit.name} - 위젯 상태 재확인');
        await _widgetService.checkWidgetStatus();
      } else if (!wasActive && habit.isActive) {
        // 비활성에서 활성으로 변경된 경우
        debugPrint('습관 활성화: ${habit.name} - 위젯 업데이트');
        await _widgetService.onHabitChanged(habit.id);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasActive ? '${habit.name} 습관이 비활성화되었습니다.' : '${habit.name} 습관이 활성화되었습니다.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('상태 변경 중 오류가 발생했습니다.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _onMenuSelected(Habit habit, String value) async {
    switch (value) {
      case 'edit':
        await _navigateToEditHabit(habit);
        break;
      case 'statistics':
        await _navigateToHabitDetail(habit);
        break;
      case 'delete':
        await _showDeleteConfirmDialog(habit);
        break;
    }
  }

  Future<void> _showDeleteConfirmDialog(Habit habit) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('습관 삭제'),
          content: Text('정말로 "${habit.name}" 습관을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteHabit(habit);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteHabit(Habit habit) async {
    try {
      await _habitService.deleteHabit(habit.id);
      await _loadHabits();
      await _widgetService.onHabitChanged(habit.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${habit.name} 습관이 삭제되었습니다.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('습관 삭제 중 오류가 발생했습니다.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _navigateToAddHabit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddHabitPage()),
    );
    // 습관 추가 페이지에서 돌아왔을 때 항상 새로고침
    _loadHabits();
    await _widgetService.updateWidget();
  }

  Future<void> _navigateToHabitDetail(Habit habit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HabitDetailPage(habit: habit)),
    );
    // 디테일 페이지에서 돌아왔을 때 항상 데이터를 새로고침
    _loadHabits();
    await _widgetService.onHabitChanged(habit.id);
  }

  Future<void> _navigateToEditHabit(Habit habit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditHabitPage(habit: habit)),
    );
    if (result == true) {
      _loadHabits();
      await _widgetService.onHabitChanged(habit.id);
    }
  }

  Future<void> _navigateToWidgetSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WidgetSettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.widgets),
            onPressed: _navigateToWidgetSettings,
            tooltip: '위젯 설정',
          ),
        ],
      ),
      body: SafeArea(
        child: _habits.isEmpty ? _buildEmptyState() : _buildHabitsList(),
      ),
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: FloatingActionButton.extended(
            onPressed: _navigateToAddHabit,
            icon: const Icon(Icons.add),
            label: const Text('습관 추가'),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: AppConstants.largePadding),
          Text(
            '아직 습관이 없습니다',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          Text(
            '새로운 습관을 추가해보세요!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: AppConstants.largePadding),
          ElevatedButton.icon(
            onPressed: _navigateToAddHabit,
            icon: const Icon(Icons.add),
            label: const Text('첫 번째 습관 추가'),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: _habits.length,
      itemBuilder: (context, index) {
        final habit = _habits[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: GestureDetector(
              onTap: () => _onHabitImageTap(habit),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: habit.isActive 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: habit.imagePaths.isNotEmpty
                      ? Image.file(
                          File(habit.imagePaths[habit.currentImageIndex % habit.imagePaths.length]),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: Icon(
                                Icons.psychology,
                                color: habit.isActive 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: Icon(
                            Icons.psychology,
                            color: habit.isActive 
                                ? Theme.of(context).colorScheme.primary 
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                ),
              ),
            ),
            title: Text(
              habit.name,
              style: TextStyle(
                fontWeight: habit.isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              '클릭: ${habit.totalClicks}회 | 연속: ${habit.streakCount}일',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: habit.isActive,
                  onChanged: (value) => _toggleHabitActive(habit),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) => _onMenuSelected(habit, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('수정'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'statistics',
                      child: Row(
                        children: [
                          Icon(Icons.analytics, size: 20),
                          SizedBox(width: 8),
                          Text('통계'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('삭제', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

          ),
        );
      },
    );
  }

  String _formatInterval(int seconds) {
    if (seconds < 60) {
      return '${seconds}초';
    } else if (seconds < 3600) {
      return '${seconds ~/ 60}분';
    } else {
      return '${seconds ~/ 3600}시간';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}시간 ${duration.inMinutes % 60}분';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}분 ${duration.inSeconds % 60}초';
    } else {
      return '${duration.inSeconds}초';
    }
  }

  Future<void> _checkWidgetIntent() async {
    try {
      // 위젯으로부터 전달받은 Intent 확인
      final prefs = await SharedPreferences.getInstance();
      final widgetResetEvent = prefs.getString('flutter.widget_reset_event');
      
      if (widgetResetEvent != null) {
        debugPrint('위젯으로부터 앱이 열림 - 이벤트 확인');
        await _checkWidgetResetEvent();
      }
      
      // 딥링크로 위젯 설정 페이지가 요청되었는지 확인
      await _checkDeepLinkIntent();
    } catch (e) {
      debugPrint('위젯 Intent 확인 오류: $e');
    }
  }
  
  Future<void> _checkDeepLinkIntent() async {
    try {
      // 현재 앱의 URI 확인 (이 부분은 플랫폼별로 구현 필요)
      final prefs = await SharedPreferences.getInstance();
      final deepLinkFlag = prefs.getBool('widget_setup_requested');
      
      if (deepLinkFlag == true) {
        // 플래그 제거
        await prefs.remove('widget_setup_requested');
        // 위젯 설정 페이지로 이동
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToWidgetSettings();
        });
        debugPrint('딥링크로 위젯 설정 페이지 열기');
      }
    } catch (e) {
      debugPrint('딥링크 확인 오류: $e');
    }
  }

  Future<void> _checkAndRefreshHabits() async {
    try {
      // 파일에서 위젯 이벤트 확인
      final eventFile = File('/data/data/com.example.habit_reminder/files/widget_reset_event.json');
      
      // 위젯 이벤트가 있으면 습관 목록 새로고침
      if (await eventFile.exists()) {
        final updatedHabits = _habitService.getAllHabits();
        setState(() {
          _habits = updatedHabits;
        });
        debugPrint('위젯 이벤트로 인한 습관 목록 새로고침');
      }
    } catch (e) {
      debugPrint('습관 목록 새로고침 확인 오류: $e');
    }
  }
}

