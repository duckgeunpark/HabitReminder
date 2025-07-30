import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/habit_model.dart';
import '../../constants/app_constants.dart';

class PhotoChangeEvent {
  final String imagePath;
  final double startPercent;
  PhotoChangeEvent(this.imagePath, this.startPercent);
}

class PhotoTimelineController {
  final List<PhotoChangeEvent> events = [];
  final int totalSeconds;

  PhotoTimelineController(this.totalSeconds);

  // 새 이벤트 추가 함수 (입력 검증 포함)
  // 이전 값보다 크거나 같아야 추가 가능
  // 추가 성공하면 true, 실패(입력값 작음)하면 false 반환
  bool addPhotoEvent(PhotoChangeEvent newEvent) {
    if (newEvent.startPercent < 0 || newEvent.startPercent > 100) {
      print('오류: 퍼센트는 0~100 범위여야 합니다.');
      return false;
    }
    if (events.isNotEmpty) {
      double lastPercent = events.last.startPercent;
      if (newEvent.startPercent < lastPercent) {
        print('오류: 입력값은 이전 값($lastPercent)보다 작거나 같으면 안 됩니다.');
        return false;
      }
      if (newEvent.startPercent == lastPercent) {
        print('오류: 중복 값은 허용되지 않습니다.');
        return false;
      }
    }

    events.add(newEvent);
    // 이벤트를 퍼센트 순으로 정렬
    events.sort((a, b) => a.startPercent.compareTo(b.startPercent));
    return true;
  }

  String getCurrentPhoto(double progress) {
    double percent = progress * 100;
    String current = events.isNotEmpty ? events.first.imagePath : 'default.jpg';
    for (var event in events) {
      if (percent >= event.startPercent) {
        current = event.imagePath;
      } else {
        break;
      }
    }
    return current;
  }

  String getPhotoAtTime(int currentSec) {
    double progress = currentSec / totalSeconds;
    return getCurrentPhoto(progress);
  }
}

class HabitFormPage extends StatefulWidget {
  final Habit? habit; // null이면 새로 생성, 있으면 수정
  final Function(Habit) onSave;

  const HabitFormPage({
    super.key,
    this.habit,
    required this.onSave,
  });

  @override
  State<HabitFormPage> createState() => _HabitFormPageState();
}

class _HabitFormPageState extends State<HabitFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  List<String> _selectedImages = [];
  int _totalSeconds = 300;
  int _hours = 0;
  int _minutes = 5;
  int _seconds = 0;
  PhotoTimelineController? _photoTimelineController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.habit != null) {
      // 수정 모드
      _nameController.text = widget.habit!.name;
      _selectedImages = List.from(widget.habit!.imagePaths);
      _totalSeconds = widget.habit!.intervalSeconds;
      
      // 기존 imageTimings를 PhotoTimelineController로 변환
      _photoTimelineController = PhotoTimelineController(_totalSeconds);
      final imageStartPoints = <String, double>{};
      
      // _imageTimings에서 각 이미지의 시작점 찾기
      for (final entry in widget.habit!.imageTimings.entries) {
        final imageIndex = entry.value;
        final percentage = entry.key;
        final imagePath = _selectedImages[imageIndex];
        
        if (!imageStartPoints.containsKey(imagePath) ||
            imageStartPoints[imagePath]! > percentage) {
          imageStartPoints[imagePath] = percentage.toDouble();
        }
      }
      
      // 시작점 순서대로 정렬하여 이벤트 추가
      final sortedEvents = imageStartPoints.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      for (final entry in sortedEvents) {
        _photoTimelineController!.addPhotoEvent(
          PhotoChangeEvent(entry.key, entry.value)
        );
      }
    } else {
      // 새로 생성 모드
      _photoTimelineController = PhotoTimelineController(_totalSeconds);
    }
    
    // 시간을 시/분/초로 분해
    _hours = _totalSeconds ~/ 3600;
    _minutes = (_totalSeconds % 3600) ~/ 60;
    _seconds = _totalSeconds % 60;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((image) => image.path));
          
          // 초기 타이밍 설정: 첫 번째 사진만 0%에서 시작
          _photoTimelineController = PhotoTimelineController(_totalSeconds);
          if (_selectedImages.isNotEmpty) {
            _photoTimelineController!.addPhotoEvent(
              PhotoChangeEvent(_selectedImages[0], 0.0)
            );
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('이미지 선택 중 오류가 발생했습니다.');
    }
  }

  Future<void> _removeImage(int index) async {
    // 이 메서드는 이제 _removeImageAtIndex로 대체됨
    _removeImageAtIndex(index);
  }

  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      _showErrorSnackBar('최소 하나의 이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // PhotoTimelineController의 이벤트를 Map<int, int> 형식으로 변환
      final Map<int, int> imageTimings = {};
      if (_photoTimelineController != null && _photoTimelineController!.events.isNotEmpty) {
        for (int i = 0; i < _photoTimelineController!.events.length; i++) {
          final event = _photoTimelineController!.events[i];
          final imageIndex = _selectedImages.indexOf(event.imagePath);
          
          if (imageIndex != -1) {
            final startPercent = event.startPercent.toInt();
            final endPercent = i < _photoTimelineController!.events.length - 1
                ? _photoTimelineController!.events[i + 1].startPercent.toInt()
                : 100;
            
            // 시작점부터 끝점까지의 모든 퍼센트에 해당 이미지 매핑
            for (int p = startPercent; p < endPercent; p++) {
              imageTimings[p] = imageIndex;
            }
            // 마지막 이벤트의 경우 100%도 포함
            if (i == _photoTimelineController!.events.length - 1) {
              imageTimings[100] = imageIndex;
            }
          }
        }
      }

      final habit = Habit(
        id: widget.habit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        imagePaths: _selectedImages,
        intervalSeconds: _totalSeconds,
        imageTimings: imageTimings,
        createdAt: widget.habit?.createdAt ?? DateTime.now(),
      );

      await widget.onSave(habit);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar('습관 저장 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _updateTotalSeconds() {
    // 기존 이벤트들을 보존
    List<PhotoChangeEvent>? existingEvents;
    if (_photoTimelineController != null) {
      existingEvents = List<PhotoChangeEvent>.from(_photoTimelineController!.events);
    }
    
    // 새로운 총 시간으로 컨트롤러 재생성
    _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
    _photoTimelineController = PhotoTimelineController(_totalSeconds);
    
    // 기존 이벤트들을 복원
    if (existingEvents != null && existingEvents.isNotEmpty) {
      for (final event in existingEvents) {
        // 이미지가 여전히 존재하는지 확인
        if (_selectedImages.contains(event.imagePath)) {
          _photoTimelineController!.addPhotoEvent(event);
        }
      }
    }
    // 이벤트가 없고 이미지가 있다면 첫 번째 이미지를 0%로 설정
    else if (_selectedImages.isNotEmpty && 
             (_photoTimelineController == null || _photoTimelineController!.events.isEmpty)) {
      _photoTimelineController!.addPhotoEvent(
        PhotoChangeEvent(_selectedImages[0], 0.0)
      );
    }
  }

  void _onReorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      
      // 이미지 순서 변경
      final String item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
      
      // 타이밍 설정이 있는 경우, 기존 퍼센트 위치는 유지하면서 이미지 경로만 업데이트
      if (_photoTimelineController != null && _photoTimelineController!.events.isNotEmpty) {
        // 기존 이벤트들의 퍼센트 위치를 저장
        final existingPercentages = _photoTimelineController!.events
            .map((e) => e.startPercent)
            .toList()
          ..sort();
        
        // 이벤트 목록을 클리어하고 새로운 이미지 순서로 재생성
        _photoTimelineController!.events.clear();
        
        // 정렬된 퍼센트 위치에 새로운 이미지 순서를 매핑
        for (int i = 0; i < existingPercentages.length && i < _selectedImages.length; i++) {
          _photoTimelineController!.addPhotoEvent(
            PhotoChangeEvent(_selectedImages[i], existingPercentages[i])
          );
        }
      }
    });
  }

  void _showDeleteImageDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 삭제'),
        content: Text('사진 ${index + 1}을(를) 삭제하시겠습니까?\n타이밍 설정도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeImageAtIndex(index);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _removeImageAtIndex(int index) {
    setState(() {
      final removedImagePath = _selectedImages[index];
      _selectedImages.removeAt(index);
      
      // 해당 이미지의 타이밍 이벤트 제거
      if (_photoTimelineController != null) {
        _photoTimelineController!.events.removeWhere(
          (event) => event.imagePath == removedImagePath
        );
      }
      
      // 이미지가 모두 제거되면 컨트롤러도 초기화
      if (_selectedImages.isEmpty) {
        _photoTimelineController = null;
      }
      // 이벤트가 비어있는 경우에만 첫 번째 이미지를 0%로 자동 설정
      else if (_photoTimelineController != null && _photoTimelineController!.events.isEmpty && _selectedImages.isNotEmpty) {
        _photoTimelineController!.addPhotoEvent(
          PhotoChangeEvent(_selectedImages[0], 0.0)
        );
      }
    });
  }

  void _updateImageTimings(int percentage, int imageIndex) {
    if (_selectedImages.isEmpty || _photoTimelineController == null) return;
    
    // 새로운 이벤트 생성
    final newEvent = PhotoChangeEvent(_selectedImages[imageIndex], percentage.toDouble());
    
    // 기존 이벤트에서 같은 이미지가 있는지 확인하고 제거
    _photoTimelineController!.events.removeWhere((event) => event.imagePath == _selectedImages[imageIndex]);
    
    // 새 이벤트 추가 시도
    final success = _photoTimelineController!.addPhotoEvent(newEvent);
    
    if (!success) {
      // 실패한 경우 기존 이벤트 복원
      _photoTimelineController!.events.clear();
      if (_selectedImages.isNotEmpty) {
        _photoTimelineController!.addPhotoEvent(
          PhotoChangeEvent(_selectedImages[0], 0.0)
        );
      }
    }
    
    setState(() {});
  }

  void _showImageTimingDialog(int currentPercentage, int imageIndex) {
    // 첫 번째 사진도 타이밍 변경 가능하도록 제한 제거

    final TextEditingController percentageController = TextEditingController(
      text: currentPercentage.toString(),
    );
    
    // 유효한 입력 범위 계산
    double minPercentage = 0.0;
    double maxPercentage = 100.0;
    
    if (_photoTimelineController != null && _photoTimelineController!.events.isNotEmpty) {
      // 현재 사진보다 앞선 순서에 있는 사진들의 타이밍 찾기
      double? latestPreviousPercent;
      for (int i = 0; i < imageIndex; i++) {
        final previousImagePath = _selectedImages[i];
        final previousEvent = _photoTimelineController!.events
            .where((e) => e.imagePath == previousImagePath)
            .firstOrNull;
        
        if (previousEvent != null) {
          if (latestPreviousPercent == null || previousEvent.startPercent > latestPreviousPercent) {
            latestPreviousPercent = previousEvent.startPercent;
          }
        }
      }
      
      // 이전 사진이 있다면 그 다음부터 설정 가능 (5% 간격)
      if (latestPreviousPercent != null) {
        minPercentage = latestPreviousPercent + 5.0;
      }
      
      // 현재 사진보다 뒤 순서에 있는 사진들의 타이밍 찾기
      double? earliestNextPercent;
      for (int i = imageIndex + 1; i < _selectedImages.length; i++) {
        final nextImagePath = _selectedImages[i];
        final nextEvent = _photoTimelineController!.events
            .where((e) => e.imagePath == nextImagePath)
            .firstOrNull;
        
        if (nextEvent != null) {
          if (earliestNextPercent == null || nextEvent.startPercent < earliestNextPercent) {
            earliestNextPercent = nextEvent.startPercent;
          }
        }
      }
      
      // 다음 사진이 있다면 그 이전까지 설정 가능 (5% 간격)
      if (earliestNextPercent != null) {
        maxPercentage = earliestNextPercent - 5.0;
      }
    }
    
    String? errorMessage;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void updatePercentage(int newPercentage) {
            setDialogState(() {
              if (newPercentage < minPercentage) {
                errorMessage = '최소 ${minPercentage.toInt()}% 이상이어야 합니다.';
              } else if (newPercentage > maxPercentage) {
                errorMessage = '최대 ${maxPercentage.toInt()}% 이하여야 합니다.';
              } else {
                percentageController.text = newPercentage.toString();
                errorMessage = null;
              }
            });
          }
          
          void validateInput() {
            final input = int.tryParse(percentageController.text);
            if (input == null) {
              errorMessage = '유효한 숫자를 입력해주세요.';
            } else if (input < minPercentage) {
              errorMessage = '최소 ${minPercentage.toInt()}% 이상 입력해주세요.';
            } else if (input > maxPercentage) {
              errorMessage = '최대 ${maxPercentage.toInt()}% 이하로 입력해주세요.';
            } else {
              errorMessage = null;
            }
            setDialogState(() {});
          }
          
          return AlertDialog(
            title: Text('사진 ${imageIndex + 1} 타이밍 설정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('이 사진이 나타날 지점을 설정해주세요.'),
                const SizedBox(height: AppConstants.defaultPadding),
                Text(
                  '유효한 범위: ${minPercentage.toInt()}% ~ ${maxPercentage.toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppConstants.smallPadding),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => updatePercentage(
                        (int.tryParse(percentageController.text) ?? currentPercentage) - 5
                      ),
                      icon: const Icon(Icons.arrow_back_ios),
                      tooltip: '5% 감소',
                    ),
                    Expanded(
                      child: TextField(
                        controller: percentageController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: '퍼센트 (0-100)',
                          suffixText: '%',
                        ),
                        onChanged: (value) {
                          validateInput();
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () => updatePercentage(
                        (int.tryParse(percentageController.text) ?? currentPercentage) + 5
                      ),
                      icon: const Icon(Icons.arrow_forward_ios),
                      tooltip: '5% 증가',
                    ),
                  ],
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: AppConstants.smallPadding),
                  Text(
                    errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: errorMessage == null ? () {
                  final percentage = int.tryParse(percentageController.text) ?? currentPercentage;
                  Navigator.pop(context);
                  setState(() {
                    _updateImageTimings(percentage, imageIndex);
                  });
                } : null,
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getTimingText(int percentage) {
    final totalSeconds = _totalSeconds;
    final calculatedSeconds = (percentage / 100 * totalSeconds).round();
    final minutes = calculatedSeconds ~/ 60;
    final seconds = calculatedSeconds % 60;
    final timeString = '${minutes}:${seconds.toString().padLeft(2, '0')}';
    return '${percentage}% (${timeString}) 지점부터 표시';
  }

  List<Widget> _buildTimingSegments() {
    if (_photoTimelineController == null || _photoTimelineController!.events.isEmpty) {
      return [];
    }

    final segments = <Widget>[];
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    // 이벤트들을 퍼센트 순으로 정렬
    final sortedEvents = List<PhotoChangeEvent>.from(_photoTimelineController!.events)
      ..sort((a, b) => a.startPercent.compareTo(b.startPercent));

    for (int i = 0; i < sortedEvents.length; i++) {
      final event = sortedEvents[i];
      final startPercentage = event.startPercent;
      
      // 다음 이벤트의 시작점을 끝점으로 사용
      double endPercentage = 100.0;
      if (i < sortedEvents.length - 1) {
        endPercentage = sortedEvents[i + 1].startPercent;
      }
      
      final imageIndex = _selectedImages.indexOf(event.imagePath);
      final segmentColor = colors[imageIndex % colors.length];
      
      final containerWidth = MediaQuery.of(context).size.width - 64; // 패딩 고려
      final segmentLeft = startPercentage / 100 * containerWidth;
      final segmentWidth = (endPercentage - startPercentage) / 100 * containerWidth;
      
      segments.add(
        Positioned(
          left: segmentLeft,
          top: 0,
          child: Container(
            width: segmentWidth,
            height: 20,
            decoration: BoxDecoration(
              color: segmentColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: segmentColor,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '사진 ${imageIndex + 1}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return segments;
  }

  List<Widget> _buildPhotoIcons() {
    if (_selectedImages.isEmpty || _photoTimelineController == null) return [];
    
    final icons = <Widget>[];
    
    if (_photoTimelineController!.events.isEmpty) return icons;
    
    // 각 구간별로 다른 색상 적용 (세그먼트와 동일한 색상)
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    
    for (int i = 0; i < _photoTimelineController!.events.length; i++) {
      final event = _photoTimelineController!.events[i];
      final imageIndex = _selectedImages.indexOf(event.imagePath);
      final startPercentage = event.startPercent;
      
      final containerWidth = MediaQuery.of(context).size.width - 64; // 패딩 고려
      final iconLeft = startPercentage / 100 * containerWidth + 20; // 아이콘 왼쪽 끝을 시작점에 맞춤
      
      icons.add(
        Positioned(
          left: iconLeft,
          top: 100, // 게이지 아래쪽에 위치 (높이 증가에 맞춰 조정)
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(
                color: colors[imageIndex % colors.length],
                width: 2,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(event.imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      );
    }
    
    return icons;
  }

  Widget _buildTimingGauge() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppConstants.defaultPadding),
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '사진 타이밍 설정',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_totalSeconds ~/ 60}:${(_totalSeconds % 60).toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.smallPadding),
          // 디버그 정보 표시
          if (_photoTimelineController != null && _photoTimelineController!.events.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '설정된 타이밍: ${_photoTimelineController!.events.map((e) => '${_selectedImages.indexOf(e.imagePath) + 1}번(${e.startPercent.toInt()}%)').join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          IgnorePointer(
            child: Container(
              height: 160, // 높이 증가
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Stack(
                children: [
                  // 게이지 배경
                  Container(
                    width: double.infinity,
                    height: 25, // 높이 증가
                    margin: const EdgeInsets.only(top: 70), // 위치 조정
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // 타이밍 세그먼트
                  Positioned(
                    top: 70, // 위치 조정
                    left: 0,
                    right: 0,
                    child: Stack(
                      children: _buildTimingSegments(),
                    ),
                  ),
                  // 사진 아이콘
                  ..._buildPhotoIcons(),
                  // 퍼센트 표시 (더 명확하게)
                  Positioned(
                    top: 15, // 위치 조정
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '0%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '100%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 중간 퍼센트 표시들
                  Positioned(
                    top: 15,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40), // 왼쪽 여백
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '25%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '50%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '75%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40), // 오른쪽 여백
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTimingList() {
    if (_selectedImages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: const Center(
          child: Text('이미지를 선택해주세요.'),
        ),
      );
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '사진 목록 (드래그해서 순서 변경)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            Text(
              '총 ${_selectedImages.length}장',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.smallPadding),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedImages.length,
          onReorder: _onReorderImages,
          itemBuilder: (context, index) {
            final imagePath = _selectedImages[index];
            
            // PhotoTimelineController에서 해당 이미지의 시작점 찾기
            double? percentage;
            if (_photoTimelineController != null) {
              final event = _photoTimelineController!.events
                  .where((e) => e.imagePath == imagePath)
                  .firstOrNull;
              percentage = event?.startPercent;
            }
            
            // 해당 이미지의 색상 가져오기
            final segmentColor = percentage != null 
                ? colors[index % colors.length].withOpacity(0.1)
                : Colors.transparent;
            
            return Card(
              key: ValueKey(imagePath),
              margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
              color: segmentColor,
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.drag_handle,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      child: Image.file(
                        File(imagePath),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
                title: Text('사진 ${index + 1}'),
                subtitle: Text(
                  percentage != null 
                      ? _getTimingText(percentage.toInt())
                      : '타이밍이 설정되지 않음',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (percentage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${percentage}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.touch_app),
                      onPressed: () => _showImageTimingDialog(percentage?.toInt() ?? 0, index),
                      tooltip: '타이밍 설정',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteImageDialog(index),
                      tooltip: '사진 삭제',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit != null ? '습관 수정' : '새 습관 추가'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '습관 이름',
                hintText: '습관의 이름을 입력하세요',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '습관 이름을 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // 시간 설정
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '알림 간격',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.smallPadding),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _hours,
                            decoration: const InputDecoration(
                              labelText: '시간',
                              suffixText: '시간',
                            ),
                            items: List.generate(25, (index) => DropdownMenuItem(
                              value: index,
                              child: Text('$index'),
                            )),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _hours = value;
                                  _updateTotalSeconds();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppConstants.smallPadding),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _minutes,
                            decoration: const InputDecoration(
                              labelText: '분',
                              suffixText: '분',
                            ),
                            items: List.generate(60, (index) => DropdownMenuItem(
                              value: index,
                              child: Text('$index'),
                            )),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _minutes = value;
                                  _updateTotalSeconds();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppConstants.smallPadding),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _seconds,
                            decoration: const InputDecoration(
                              labelText: '초',
                              suffixText: '초',
                            ),
                            items: List.generate(60, (index) => DropdownMenuItem(
                              value: index,
                              child: Text('$index'),
                            )),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _seconds = value;
                                  _updateTotalSeconds();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // 이미지 선택
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '이미지 선택',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('이미지 추가'),
                        ),
                      ],
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.smallPadding),
                      _buildImageTimingList(),
                    ],
                  ],
                ),
              ),
            ),
            
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: AppConstants.defaultPadding),
              _buildTimingGauge(),
            ],
            
            const SizedBox(height: AppConstants.defaultPadding),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveHabit,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Text(
                    widget.habit != null ? '수정하기' : '추가하기',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 