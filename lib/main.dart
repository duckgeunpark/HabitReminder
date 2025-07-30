import 'dart:io';
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

class _HomePageState extends State<HomePage> {
  final HabitService _habitService = HabitService();
  final HomeWidgetService _widgetService = HomeWidgetService();
  final TimerService _timerService = TimerService();
  List<Habit> _habits = [];

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _checkWidgetStatus();
  }

  @override
  void dispose() {
    _timerService.dispose();
    super.dispose();
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
    if (result == true) {
      _loadHabits();
      await _widgetService.updateWidget();
    }
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
      body: _habits.isEmpty ? _buildEmptyState() : _buildHabitsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddHabit,
        icon: const Icon(Icons.add),
        label: const Text('습관 추가'),
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
}

