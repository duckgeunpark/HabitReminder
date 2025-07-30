import 'package:flutter/material.dart';
import '../../widgets/home_widget_service.dart';
import '../../constants/app_constants.dart';

class WidgetSettingsPage extends StatefulWidget {
  const WidgetSettingsPage({super.key});

  @override
  State<WidgetSettingsPage> createState() => _WidgetSettingsPageState();
}

class _WidgetSettingsPageState extends State<WidgetSettingsPage> {
  final HomeWidgetService _widgetService = HomeWidgetService();
  bool _hasActiveHabits = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkActiveHabits();
  }

  Future<void> _checkActiveHabits() async {
    final hasActive = await _widgetService.hasActiveHabits();
    setState(() {
      _hasActiveHabits = hasActive;
      _isLoading = false;
    });
  }

  Future<void> _updateWidget() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _widgetService.updateWidget();
      await _checkActiveHabits();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위젯 기능이 임시로 비활성화되었습니다.'),
            backgroundColor: Colors.orange,
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
                  // 위젯 상태 카드
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: AppConstants.smallPadding),
                              Text(
                                '위젯 기능 임시 비활성화',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.defaultPadding),
                          Text(
                            '위젯 기능이 현재 임시로 비활성화되었습니다.\n'
                            'Flutter 버전 호환성 문제로 인해 위젯 기능을 나중에 구현할 예정입니다.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.largePadding),

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
                                _hasActiveHabits ? Icons.check_circle : Icons.info_outline,
                                color: _hasActiveHabits ? Colors.green : Colors.grey,
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
                            _hasActiveHabits
                                ? '활성 습관이 있어 위젯을 사용할 수 있습니다.'
                                : '활성 습관이 없어 위젯을 사용할 수 없습니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (!_hasActiveHabits) ...[
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

                  // 개발 예정 기능
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '개발 예정 기능',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppConstants.defaultPadding),
                          _buildFeatureItem(
                            '홈 화면 위젯',
                            '설정한 시간 간격에 따라 이미지가 자동으로 변경되는 위젯',
                            Icons.widgets,
                          ),
                          _buildFeatureItem(
                            '위젯 클릭 리셋',
                            '위젯을 클릭하면 타이머가 리셋되고 첫 번째 이미지로 돌아감',
                            Icons.touch_app,
                          ),
                          _buildFeatureItem(
                            '실시간 통계',
                            '총 클릭 수와 연속 달성 일수가 위젯에 표시',
                            Icons.analytics,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.largePadding),

                  // 현재 사용 가능한 기능
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
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: AppConstants.smallPadding),
                              Text(
                                '현재 사용 가능한 기능',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.defaultPadding),
                          _buildAvailableFeatureItem(
                            '습관 관리',
                            '습관 생성, 수정, 삭제, 활성화/비활성화',
                            Icons.psychology,
                          ),
                          _buildAvailableFeatureItem(
                            '이미지 관리',
                            '다중 이미지 선택 및 관리',
                            Icons.image,
                          ),
                          _buildAvailableFeatureItem(
                            '타이머 기능',
                            '설정한 시간에 따라 이미지 자동 변경',
                            Icons.timer,
                          ),
                          _buildAvailableFeatureItem(
                            '통계 관리',
                            '클릭 수, 연속 달성 일수 추적',
                            Icons.analytics,
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

  Widget _buildFeatureItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableFeatureItem(String title, String description, IconData icon) {
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