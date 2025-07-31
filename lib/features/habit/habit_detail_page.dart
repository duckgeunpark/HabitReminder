import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/habit_model.dart';
import '../../features/habit/habit_service.dart';
import '../../features/habit/edit_habit_page.dart';
import '../../constants/app_constants.dart';
import 'dart:async'; // Added for Timer

class HabitDetailPage extends StatefulWidget {
  final Habit habit;

  const HabitDetailPage({super.key, required this.habit});

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  final HabitService _habitService = HabitService();
  late Habit _currentHabit;
  bool _isLoading = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _currentHabit = widget.habit;
    _startUpdateTimer();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // 활성화된 시간이 실시간으로 업데이트되도록 setState 호출
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentHabit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editHabit(),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 습관 정보 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '습관 정보',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                    _buildInfoRow('이름', _currentHabit.name),
                    _buildInfoRow('이미지 개수', '${_currentHabit.imagePaths.length}개'),
                    _buildInfoRow('시간 간격', _formatInterval(_currentHabit.intervalSeconds)),
                    _buildInfoRow('생성일', _formatDate(_currentHabit.createdAt)),
                    _buildInfoRow('상태', _currentHabit.isActive ? '활성' : '비활성'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppConstants.largePadding),
            
            // 통계 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '통계',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                    _buildInfoRow('총 클릭 수', '${_currentHabit.totalClicks}회'),
                    _buildInfoRow('연속 달성', '${_currentHabit.streakCount}일'),
                    _buildInfoRow('활성화된 시간', _formatActiveTime()),
                    if (_currentHabit.clickTimes.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.smallPadding),
                      _buildInfoRow('평균 클릭 시간', _formatAverageClickTime()),
                      const SizedBox(height: AppConstants.smallPadding),
                      _buildInfoRow('최고 기록', _formatBestClickTime()),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppConstants.largePadding),
            
            // 클릭 시간 기록 카드
            if (_currentHabit.clickTimes.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '클릭 시간 기록',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _currentHabit.clickTimes.length,
                          itemBuilder: (context, index) {
                            final clickTime = _currentHabit.clickTimes[index];
                            final timestamp = _currentHabit.clickTimestamps[index];
                            final reversedIndex = _currentHabit.clickTimes.length - 1 - index;
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Text(
                                  '${reversedIndex + 1}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                '${_formatClickTime(clickTime)}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                _formatDate(timestamp),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              trailing: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getClickTimeColor(clickTime),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: AppConstants.largePadding),
            ],
            
            const SizedBox(height: AppConstants.largePadding),
            
            // 액션 버튼들
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _toggleActive,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentHabit.isActive 
                          ? Colors.blue 
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(_currentHabit.isActive ? Icons.pause : Icons.play_arrow),
                    label: Text(_currentHabit.isActive ? '비활성화' : '활성화'),
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _showResetConfirmDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('통계 초기화'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatActiveTime() {
    int totalSeconds = _currentHabit.totalActiveSeconds;
    
    // 현재 활성화 중인 경우 현재까지의 시간도 추가
    if (_currentHabit.isActive && _currentHabit.activatedTime != null) {
      final now = DateTime.now();
      final currentActiveDuration = now.difference(_currentHabit.activatedTime!);
      totalSeconds += currentActiveDuration.inSeconds;
    }
    
    if (totalSeconds < 60) {
      return '${totalSeconds}초';
    } else if (totalSeconds < 3600) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return '${minutes}분 ${seconds}초';
    } else {
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      return '${hours}시간 ${minutes}분';
    }
  }

  String _formatAverageClickTime() {
    if (_currentHabit.clickTimes.isEmpty) {
      return '0초';
    }
    final totalSeconds = _currentHabit.clickTimes.reduce((a, b) => a + b);
    final averageSeconds = totalSeconds / _currentHabit.clickTimes.length;
    return '${averageSeconds.toInt()}초';
  }

  String _formatBestClickTime() {
    if (_currentHabit.clickTimes.isEmpty) {
      return '0초';
    }
    return '${_currentHabit.clickTimes.reduce((a, b) => a > b ? a : b)}초';
  }

  Color _getClickTimeColor(int clickTime) {
    if (clickTime < 10) {
      return Colors.green;
    } else if (clickTime < 20) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _formatClickTime(int seconds) {
    if (seconds < 60) {
      return '${seconds}초';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}분 ${remainingSeconds}초';
    }
  }

  Future<void> _editHabit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditHabitPage(habit: _currentHabit),
      ),
    );
    
    if (result == true) {
      // 수정된 습관 정보를 다시 가져옴
      final updatedHabit = _habitService.getHabitById(_currentHabit.id);
      if (updatedHabit != null) {
        setState(() {
          _currentHabit = updatedHabit;
        });
      }
    }
  }

  Future<void> _showDeleteDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('습관 삭제'),
          content: Text('정말로 "${_currentHabit.name}" 습관을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteHabit();
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showResetConfirmDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('통계 초기화'),
          content: Text(
            '정말로 "${_currentHabit.name}" 습관의 통계를 초기화하시겠습니까?\n\n'
            '• 총 클릭 수: ${_currentHabit.totalClicks}회 → 0회\n'
            '• 연속 달성: ${_currentHabit.streakCount}일 → 0일\n\n'
            '이 작업은 되돌릴 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetStatistics();
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('초기화'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteHabit() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _habitService.deleteHabit(_currentHabit.id);
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_currentHabit.name} 습관이 삭제되었습니다.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('습관 삭제 중 오류가 발생했습니다.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActive() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _habitService.toggleHabitActive(_currentHabit.id);
      
      // 업데이트된 습관 정보를 가져옴
      final updatedHabit = _habitService.getHabitById(_currentHabit.id);
      if (updatedHabit != null) {
        setState(() {
          _currentHabit = updatedHabit;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_currentHabit.isActive ? '습관이 활성화되었습니다.' : '습관이 비활성화되었습니다.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('상태 변경 중 오류가 발생했습니다.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 통계 초기화 (클릭수와 연속 달성일을 0으로)
  Future<void> _resetStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentHabit.totalClicks = 0;
      _currentHabit.streakCount = 0;
      _currentHabit.lastResetTime = null;
      _currentHabit.totalActiveSeconds = 0;
      _currentHabit.activatedTime = null;
      _currentHabit.clickTimes = [];
      _currentHabit.clickTimestamps = [];
      
      await _habitService.updateHabit(_currentHabit);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('통계가 초기화되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('통계 초기화 중 오류가 발생했습니다: $e'),
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
} 