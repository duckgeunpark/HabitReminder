import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'data/habit_model.dart';
import 'features/habit/habit_service.dart';
import 'features/habit/add_habit_page.dart';
import 'features/habit/habit_detail_page.dart';
import 'features/habit/edit_habit_page.dart';
import 'features/widget/widget_settings_page.dart';
import 'widgets/home_widget_service.dart';
import 'services/timer_service.dart';
import 'constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  final HabitService _habitService = HabitService();
  final HomeWidgetService _widgetService = HomeWidgetService();
  final TimerService _timerService = TimerService();
  List<Habit> _habits = [];

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _checkWidgetStatus();
    _startActiveTimeTimer();
    _checkWidgetResetEvent();
    
    // 앱이 포그라운드에 올 때마다 위젯 이벤트 확인
    WidgetsBinding.instance.addObserver(this);
    
    // 위젯으로부터 앱이 열렸는지 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWidgetIntent();
    });
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
      // 앱이 포그라운드에 올 때 위젯 이벤트 확인
      _checkWidgetResetEvent();
    }
  }

  Future<void> _checkWidgetResetEvent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resetEventString = prefs.getString('widget_reset_event');
      
      if (resetEventString != null) {
        final resetEvent = jsonDecode(resetEventString);
        final habitId = resetEvent['habit_id'] as String;
        
        // 습관 리셋 처리
        await _habitService.resetHabit(habitId);
        
        // 습관의 이미지를 1번으로 초기화
        final habit = _habitService.getHabitById(habitId);
        if (habit != null) {
          habit.currentImageIndex = 0;
          await _habitService.updateHabit(habit);
          
          // 위젯 데이터를 올바른 이미지 경로로 업데이트
          final widgetData = {
            'habit_id': habit.id,
            'habit_name': habit.name,
            'image_path': habit.getCurrentImage() ?? '',
            'total_clicks': habit.totalClicks,
            'streak_count': habit.streakCount,
            'updated_at': DateTime.now().toIso8601String(),
          };
          
          await prefs.setString('widget_habit_data', jsonEncode(widgetData));
          debugPrint('위젯 클릭 후 이미지 경로 업데이트: ${habit.getCurrentImage()}');
        }
        
        await _loadHabits();
        await _widgetService.updateWidget();
        
        // 리셋 이벤트 삭제
        await prefs.remove('widget_reset_event');
        
        if (mounted) {
          if (habit != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${habit.name} 습관이 위젯에서 리셋되었습니다!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('위젯 리셋 이벤트 확인 오류: $e');
    }
  }

  void _startActiveTimeTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // 위젯 이벤트 확인 (매초마다)
        _checkWidgetResetEvent();
        _checkWidgetUpdateNotification();
        
        // 활성 습관들의 이미지 변경 확인 및 활성화 시간 업데이트
        final activeHabits = _habitService.getActiveHabits();
        bool hasChanges = false;
        
        for (final habit in activeHabits) {
          // 활성화된 시간 실시간 업데이트
          if (habit.isActive && habit.activatedTime != null) {
            final now = DateTime.now();
            final activeDuration = now.difference(habit.activatedTime!);
            final newTotalActiveSeconds = habit.totalActiveSeconds + activeDuration.inSeconds;
            
            if (habit.totalActiveSeconds != newTotalActiveSeconds) {
              habit.totalActiveSeconds = newTotalActiveSeconds;
              habit.activatedTime = now; // 새로운 기준점 설정
              _habitService.updateHabit(habit);
              hasChanges = true;
              debugPrint('습관 "${habit.name}" 활성화 시간 업데이트: ${habit.totalActiveSeconds}초');
            }
          }
          
          if (habit.imagePaths.isNotEmpty) {
            final now = DateTime.now();
            final lastUpdate = habit.lastResetTime ?? habit.createdAt;
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
                _habitService.updateHabit(habit);
                hasChanges = true;
                debugPrint('습관 "${habit.name}" 이미지 변경: ${habit.getCurrentImage()} (${elapsedSeconds}초)');
                
                // 위젯 업데이트 (캐시 방지)
                _widgetService.updateWidgetOnImageChange(habit.id);
              }
            } else {
              // 타이밍 설정이 없으면 전체 시간을 균등 분할
              final totalSeconds = habit.intervalSeconds;
              final imageCount = habit.imagePaths.length;
              final secondsPerImage = totalSeconds / imageCount;
              
              // 현재 시간에 해당하는 이미지 인덱스 계산 (시간이 초과되어도 계속 증가)
              final currentImageIndex = (elapsedSeconds / secondsPerImage).floor();
              final actualImageIndex = currentImageIndex % imageCount;
              
              // 이미지 인덱스가 변경되었으면 업데이트
              if (habit.currentImageIndex != actualImageIndex) {
                habit.currentImageIndex = actualImageIndex;
                _habitService.updateHabit(habit);
                hasChanges = true;
                debugPrint('습관 "${habit.name}" 이미지 변경: ${habit.getCurrentImage()} (${elapsedSeconds}초)');
                
                // 위젯 업데이트 (캐시 방지)
                _widgetService.updateWidgetOnImageChange(habit.id);
              }
            }
          }
        }
        
        if (hasChanges) {
          // 변경사항이 있으면 목록 새로고침
          final updatedHabits = _habitService.getAllHabits();
          setState(() {
            _habits = updatedHabits;
          });
          
          // 위젯도 함께 업데이트
          _widgetService.updateWidget();
        }
      }
    });
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

  Future<void> _onHabitImageTap(Habit habit) async {
    if (habit.isActive) {
      try {
        await _habitService.resetHabit(habit.id);
        await _loadHabits();
        await _widgetService.onHabitChanged(habit.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${habit.name} 습관이 초기화되었습니다!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('습관 초기화 중 오류가 발생했습니다.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else {
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
      await _habitService.toggleHabitActive(habit.id);
      await _loadHabits();
      await _widgetService.onHabitChanged(habit.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(habit.isActive ? '${habit.name} 습관이 비활성화되었습니다.' : '${habit.name} 습관이 활성화되었습니다.'),
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
      final widgetResetEvent = prefs.getString('widget_reset_event');
      
      if (widgetResetEvent != null) {
        debugPrint('위젯으로부터 앱이 열림 - 이벤트 확인');
        await _checkWidgetResetEvent();
      }
    } catch (e) {
      debugPrint('위젯 Intent 확인 오류: $e');
    }
  }
}

