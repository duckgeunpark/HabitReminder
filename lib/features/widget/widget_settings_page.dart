import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/home_widget_service.dart';
import '../../constants/app_constants.dart';
import '../../data/habit_model.dart';
import '../../features/habit/habit_service.dart';
import 'dart:convert'; // Added for jsonEncode

class WidgetSettingsPage extends StatefulWidget {
  const WidgetSettingsPage({super.key});

  @override
  State<WidgetSettingsPage> createState() => _WidgetSettingsPageState();
}

class _WidgetSettingsPageState extends State<WidgetSettingsPage> {
  final HomeWidgetService _widgetService = HomeWidgetService();
  final HabitService _habitService = HabitService();
  List<Habit> _activeHabits = [];
  String? _selectedHabitId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveHabits();
  }

  Future<void> _loadActiveHabits() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final activeHabits = _habitService.getActiveHabits();
      setState(() {
        _activeHabits = activeHabits;
        _isLoading = false;
      });

      // 현재 선택된 습관 ID 가져오기
      final prefs = await SharedPreferences.getInstance();
      final currentWidgetHabitId = prefs.getString('flutter.selected_habit_id');
      if (currentWidgetHabitId != null && activeHabits.any((h) => h.id == currentWidgetHabitId)) {
        setState(() {
          _selectedHabitId = currentWidgetHabitId;
        });
      } else if (activeHabits.isNotEmpty && activeHabits.length == 1) {
        // 활성 습관이 하나뿐인 경우에만 자동 선택
        setState(() {
          _selectedHabitId = activeHabits.first.id;
        });
        await _saveSelectedHabit(activeHabits.first.id);
      }
      
      // 위젯 설정 요청 플래그 확인 및 제거
      final widgetSetupRequested = prefs.getBool('widget_setup_requested');
      if (widgetSetupRequested == true) {
        await prefs.remove('widget_setup_requested');
        if (mounted) {
          if (activeHabits.isNotEmpty) {
            _showHabitSelectionGuide();
          } else {
            _showNoActiveHabitsMessage();
          }
        }
      }
    } catch (e) {
      debugPrint('활성 습관 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showHabitSelectionGuide() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('위젯에 표시할 습관을 선택해주세요!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '확인',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    });
  }

  void _showNoActiveHabitsMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('활성화된 습관이 없습니다. 먼저 습관을 활성화해주세요.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '닫기',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    });
  }

  Future<void> _saveSelectedHabit(String habitId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('flutter.selected_habit_id', habitId);
      
      // 선택된 습관 정보 가져오기
      final habit = _habitService.getHabitById(habitId);
      if (habit != null) {
        // 위젯 데이터 즉시 업데이트
        final widgetData = {
          'habit_id': habit.id,
          'habit_name': habit.name,
          'image_path': habit.getCurrentImage() ?? '',
          'total_clicks': habit.totalClicks,
          'streak_count': habit.streakCount,
          'updated_at': DateTime.now().toIso8601String(),
          'image_key': '${habit.id}_${habit.currentImageIndex}_${DateTime.now().millisecondsSinceEpoch}', // 캐시 방지용 키
        };
        
        await prefs.setString('flutter.widget_habit_data', jsonEncode(widgetData));
        debugPrint('위젯 설정 저장 완료: ${habit.name}');
        
        // 위젯 강제 업데이트
        await _widgetService.forceUpdateWidget();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위젯이 "${habit?.name}" 습관으로 설정되었습니다!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('위젯 설정 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('위젯 설정 저장 중 오류가 발생했습니다.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _updateWidget() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _widgetService.updateWidget();
      await _loadActiveHabits();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위젯이 업데이트되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위젯 업데이트 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _forceUpdateWidget() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _widgetService.forceUpdateWidget();
      await _loadActiveHabits();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위젯이 강제로 업데이트되었습니다.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위젯 강제 업데이트 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위젯 설정'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _updateWidget,
              tooltip: '위젯 업데이트',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 활성 습관 선택
                  if (_activeHabits.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.widgets,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: AppConstants.smallPadding),
                                Text(
                                  '위젯에 표시할 습관 선택',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.defaultPadding),
                            Text(
                              '위젯에 표시할 습관을 선택하세요. 위젯을 클릭하면 해당 습관이 리셋됩니다.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: AppConstants.defaultPadding),
                            if (_selectedHabitId == null && _activeHabits.length > 1)
                              Container(
                                padding: const EdgeInsets.all(AppConstants.smallPadding),
                                margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppConstants.smallPadding),
                                    Expanded(
                                      child: Text(
                                        '위젯에 표시할 습관을 선택해주세요',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ...(_activeHabits.map((habit) => _buildHabitSelectionTile(habit))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.largePadding),
                  ],

                  // 활성 습관 상태
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _activeHabits.isNotEmpty ? Icons.check_circle : Icons.info_outline,
                                color: _activeHabits.isNotEmpty ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: AppConstants.smallPadding),
                              Text(
                                '활성 습관 상태',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.defaultPadding),
                          Text(
                            _activeHabits.isNotEmpty
                                ? '활성 습관 ${_activeHabits.length}개가 있어 위젯을 사용할 수 있습니다.'
                                : '활성 습관이 없어 위젯을 사용할 수 없습니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (_activeHabits.isEmpty) ...[
                            const SizedBox(height: AppConstants.smallPadding),
                            Text(
                              '습관을 활성화하면 위젯을 사용할 수 있습니다.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.largePadding),

                  // 위젯 기능 설명
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.touch_app,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: AppConstants.smallPadding),
                              Text(
                                '위젯 기능',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.defaultPadding),
                          _buildFeatureItem(
                            '실시간 이미지 표시',
                            '선택한 습관의 현재 이미지가 위젯에 실시간으로 표시됩니다.',
                            Icons.image,
                          ),
                          _buildFeatureItem(
                            '위젯 클릭 리셋',
                            '위젯을 클릭하면 선택된 습관이 리셋되고 첫 번째 이미지로 돌아갑니다.',
                            Icons.refresh,
                          ),
                          _buildFeatureItem(
                            '앱 실행 없이 리셋',
                            '앱을 실행하지 않고도 위젯을 길게 눌러 설정을 변경할 수 있습니다.',
                            Icons.settings,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.largePadding),
                  
                  // 강제 업데이트 버튼 (디버그용)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '위젯 디버그',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppConstants.defaultPadding),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _forceUpdateWidget,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('위젯 강제 업데이트'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHabitSelectionTile(Habit habit) {
    final isSelected = _selectedHabitId == habit.id;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      color: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer 
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected 
              ? Theme.of(context).colorScheme.onPrimaryContainer 
              : Theme.of(context).colorScheme.primary,
          child: Icon(
            Icons.psychology,
            color: isSelected 
                ? Theme.of(context).colorScheme.primaryContainer 
                : Colors.white,
          ),
        ),
        title: Text(
          habit.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected 
                ? Theme.of(context).colorScheme.onPrimaryContainer 
                : null,
          ),
        ),
        subtitle: Text(
          '클릭: ${habit.totalClicks}회 | 연속: ${habit.streakCount}일',
          style: TextStyle(
            color: isSelected 
                ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        trailing: isSelected 
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              )
            : null,
        onTap: () async {
          setState(() {
            _selectedHabitId = habit.id;
          });
          await _saveSelectedHabit(habit.id);
        },
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppConstants.defaultPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 