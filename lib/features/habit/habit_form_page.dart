import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/habit_model.dart';
import '../../constants/app_constants.dart';
import 'dart:math';

class PhotoTimingBox extends StatefulWidget {
  final List<String> images;
  final Map<int, int> imageTimings; // percentage -> imageIndex
  final Function(int percentage, int imageIndex) onTimingChanged;

  const PhotoTimingBox({
    super.key,
    required this.images,
    required this.imageTimings,
    required this.onTimingChanged,
  });

  @override
  State<PhotoTimingBox> createState() => _PhotoTimingBoxState();
}

class _PhotoTimingBoxState extends State<PhotoTimingBox> {
  final List<Color> colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
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
          Text(
            '사진 타이밍 설정',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          
          // 눈금과 게이지 박스를 같은 크기로 맞춤
          LayoutBuilder(
            builder: (context, constraints) {
              final gaugeWidth = constraints.maxWidth;
              
              return Column(
                children: [
                  // 눈금 표시
                  Container(
                    height: 30,
                    width: gaugeWidth, // 게이지와 정확히 같은 크기
                    child: Row(
                      children: List.generate(11, (index) {
                        final percentage = index * 10;
                        return Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$percentage',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 1,
                                height: 8,
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  
                  const SizedBox(height: AppConstants.smallPadding),
                  
                  // 타이밍 박스 (클릭 불가능)
                  Container(
                    height: 30,
                    width: gaugeWidth*0.95,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 색상 채우기
                        ..._buildColorSegments(gaugeWidth),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildColorSegments([double? gaugeWidth]) {
    final segments = <Widget>[];
    
    if (widget.imageTimings.isEmpty) {
      // 타이밍이 설정되지 않은 경우 첫 번째 이미지로 전체 채우기
      if (widget.images.isNotEmpty) {
        segments.add(
          Container(
            width: double.infinity,
            height: 30,
            decoration: BoxDecoration(
              color: colors[0].withOpacity(0.6),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
          ),
        );
      }
      return segments;
    }

    // 퍼센트 순으로 정렬
    final sortedTimings = widget.imageTimings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (int i = 0; i < sortedTimings.length; i++) {
      final entry = sortedTimings[i];
      final startPercentage = entry.key;
      final imageIndex = entry.value;
      
      // 마지막 사진은 100%까지 채우기
      double endPercentage = 100.0;
      if (i < sortedTimings.length - 1) {
        endPercentage = sortedTimings[i + 1].key.toDouble();
      }
      
      // 실제 게이지 너비 사용
      final actualGaugeWidth = gaugeWidth ?? (MediaQuery.of(context).size.width - 64);
      final segmentWidth = (endPercentage - startPercentage) / 100 * actualGaugeWidth;
      final segmentLeft = startPercentage / 100 * actualGaugeWidth;
      
      segments.add(
        Positioned(
          left: segmentLeft,
          top: 0,
          child: Container(
            width: segmentWidth,
            height: 30,
            decoration: BoxDecoration(
              color: colors[imageIndex % colors.length].withOpacity(0.6),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
          ),
        ),
      );
    }

    return segments;
  }

  List<Widget> _buildTimingInfo() {
    final info = <Widget>[];
    
    if (widget.imageTimings.isEmpty) {
      info.add(
        Text(
          '타이밍이 설정되지 않았습니다. 아래 목록에서 사진을 선택하여 설정하세요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
      return info;
    }

    final sortedTimings = widget.imageTimings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedTimings) {
      final percentage = entry.key;
      final imageIndex = entry.value;
      
      if (imageIndex < widget.images.length) {
        info.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[imageIndex % colors.length],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '사진 ${imageIndex + 1}: ${percentage}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      }
    }

    return info;
  }

  String _getCurrentImageInfo() {
    if (widget.imageTimings.isEmpty) {
      return widget.images.isNotEmpty ? '사진 1' : '없음';
    }
    
    final sortedTimings = widget.imageTimings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    if (sortedTimings.isNotEmpty) {
      final lastEntry = sortedTimings.last;
      final imageIndex = lastEntry.value;
      return '사진 ${imageIndex + 1}';
    }
    
    return '없음';
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
  final _nameFocusNode = FocusNode();
  
  List<String> _selectedImages = [];
  int _totalSeconds = 300;
  int _hours = 0;
  int _minutes = 5;
  int _seconds = 0;
  Map<int, int> _imageTimings = {}; // percentage -> imageIndex
  bool _isLoading = false;
  bool _isNameFieldTouched = false;

  // 랜덤 습관 이름 목록
  final List<String> _suggestedHabitNames = [
    '물 마시기',
    '허리 피기',
    '웃기',
    '스트레칭',
    '깊은 숨쉬기',
    '명상하기',
    '감사하기',
    '긍정적인 생각하기',
    '걷기',
    '스트레스 해소하기',
    '기분 전환하기',
    '집중하기',
    '휴식하기',
    '운동하기',
    '독서하기',
  ];

  @override
  void initState() {
    super.initState();
    
    if (widget.habit != null) {
      // 수정 모드
      _nameController.text = widget.habit!.name;
      _selectedImages = List.from(widget.habit!.imagePaths);
      _totalSeconds = widget.habit!.intervalSeconds;
      _imageTimings = Map.from(widget.habit!.imageTimings);
    } else {
      // 새 습관 생성 모드 - 랜덤한 이름 설정
      final random = Random();
      final randomName = _suggestedHabitNames[random.nextInt(_suggestedHabitNames.length)];
      _nameController.text = randomName;
    }
    
    // 시간을 시/분/초로 분해
    _hours = _totalSeconds ~/ 3600;
    _minutes = (_totalSeconds % 3600) ~/ 60;
    _seconds = _totalSeconds % 60;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
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
          final originalLength = _selectedImages.length;
          _selectedImages.addAll(images.map((image) => image.path));
          
          // 첫 번째 이미지가 추가되는 경우에만 0% 할당
          if (originalLength == 0) {
            _imageTimings[0] = 0;
          }
          // 기존 이미지가 있는 상태에서는 새로 추가된 이미지들은 타이밍 미설정 상태로 둠
        });
      }
    } catch (e) {
      _showErrorSnackBar('이미지 선택 중 오류가 발생했습니다.');
    }
  }

  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) {
      // 첫 번째 오류 필드에 포커스
      FocusScope.of(context).requestFocus(_nameFocusNode);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 퍼센트를 시간(초)로 변환
      final Map<int, int> imageTimingsSeconds = {};
      for (final entry in _imageTimings.entries) {
        final percentage = entry.key;
        final imageIndex = entry.value;
        final seconds = (_totalSeconds * percentage / 100).round();
        imageTimingsSeconds[seconds] = imageIndex;
      }

      final habitName = _nameController.text.trim().isEmpty 
          ? _suggestedHabitNames[DateTime.now().millisecondsSinceEpoch % _suggestedHabitNames.length]
          : _nameController.text.trim();

      final habit = Habit(
        id: widget.habit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: habitName,
        imagePaths: _selectedImages,
        intervalSeconds: _totalSeconds,
        createdAt: widget.habit?.createdAt ?? DateTime.now(),
        isActive: widget.habit?.isActive ?? true,
        currentImageIndex: widget.habit?.currentImageIndex ?? 0,
        lastResetTime: widget.habit?.lastResetTime,
        streakCount: widget.habit?.streakCount ?? 0,
        totalClicks: widget.habit?.totalClicks ?? 0,
        imageTimings: _imageTimings, // 퍼센트 기반 (수정 시 사용)
        imageTimingsSeconds: imageTimingsSeconds, // 시간 기반 (실제 이미지 변경 시 사용)
        clickedImageIndex: widget.habit?.clickedImageIndex ?? 0,
        activatedTime: widget.habit?.activatedTime,
        totalActiveSeconds: widget.habit?.totalActiveSeconds ?? 0,
      );

      widget.onSave(habit);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('습관 저장 중 오류가 발생했습니다: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
        setState(() {
          _isLoading = false;
        });
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
    _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
  }

  void _onReorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      
      // 이미지 순서만 변경 (타이밍은 그대로 유지)
      final String item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  void _showDeleteImageDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 삭제'),
        content: Text('사진 ${index + 1}을(를) 삭제하시겠습니까?'),
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
      _selectedImages.removeAt(index);
      
      // 삭제된 이미지의 타이밍 제거
      _imageTimings.removeWhere((key, value) => value == index);
      
      // 삭제된 이미지보다 뒤에 있는 이미지들의 인덱스 조정
      final newImageTimings = <int, int>{};
      for (final entry in _imageTimings.entries) {
        int newImageIndex = entry.value;
        if (entry.value > index) {
          newImageIndex = entry.value - 1;
        }
        newImageTimings[entry.key] = newImageIndex;
      }
      _imageTimings = newImageTimings;
    });
  }

  String _formatTimeFromPercentage(int percentage) {
    final totalSeconds = _totalSeconds;
    final calculatedSeconds = (percentage / 100 * totalSeconds).round();
    final minutes = calculatedSeconds ~/ 60;
    final seconds = calculatedSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  void _onTimingChanged(int percentage, int imageIndex) {
    setState(() {
      // 기존에 같은 사진의 타이밍이 있다면 제거
      _imageTimings.removeWhere((key, value) => value == imageIndex);
      // 새로운 타이밍 추가
      _imageTimings[percentage] = imageIndex;
    });
  }

  void _showTimingDialog(int imageIndex) {
    // 현재 이미지의 타이밍 정보 확인
    int? currentPercentage;
    for (final entry in _imageTimings.entries) {
      if (entry.value == imageIndex) {
        currentPercentage = entry.key;
        break;
      }
    }
    
    // 허용 범위 계산
    int minPercentage = 0;
    int maxPercentage = 100;
    
    if (imageIndex == 0) {
      // 첫 번째 사진은 0%로 시작
      minPercentage = 0;
      maxPercentage = 100;
    } else {
      // 이전 사진들 중 가장 큰 퍼센트 찾기
      int? previousMaxPercentage;
      for (final entry in _imageTimings.entries) {
        if (entry.value < imageIndex) {
          if (previousMaxPercentage == null || entry.key > previousMaxPercentage) {
            previousMaxPercentage = entry.key;
          }
        }
      }
      
      // 다음 사진들 중 가장 작은 퍼센트 찾기
      int? nextMinPercentage;
      for (final entry in _imageTimings.entries) {
        if (entry.value > imageIndex) {
          if (nextMinPercentage == null || entry.key < nextMinPercentage) {
            nextMinPercentage = entry.key;
          }
        }
      }
      
      // 허용 범위 계산
      if (previousMaxPercentage != null) {
        minPercentage = previousMaxPercentage + 5;
      } else {
        minPercentage = 5;
      }
      
      if (nextMinPercentage != null) {
        maxPercentage = nextMinPercentage - 5;
      } else {
        maxPercentage = 100;
      }
    }
    
    // 현재 값이 허용 범위를 벗어나면 최소값으로 설정
    int initialValue = currentPercentage ?? minPercentage;
    if (initialValue < minPercentage) {
      initialValue = minPercentage;
    }
    if (initialValue > maxPercentage) {
      initialValue = maxPercentage;
    }
    
    final TextEditingController percentageController = TextEditingController(
      text: initialValue.toString(),
    );
    
    String? errorMessage;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void updatePercentage(int newPercentage) {
            setDialogState(() {
              if (newPercentage < minPercentage) {
                errorMessage = '최소 ${minPercentage}% 이상이어야 합니다.';
              } else if (newPercentage > maxPercentage) {
                errorMessage = '최대 ${maxPercentage}% 이하여야 합니다.';
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
              errorMessage = '최소 ${minPercentage}% 이상 입력해주세요.';
            } else if (input > maxPercentage) {
              errorMessage = '최대 ${maxPercentage}% 이하로 입력해주세요.';
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
                  '허용 범위: ${minPercentage}% ~ ${maxPercentage}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppConstants.smallPadding),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => updatePercentage(
                        (int.tryParse(percentageController.text) ?? initialValue) - 5
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
                          labelText: '퍼센트',
                          suffixText: '%',
                        ),
                        onChanged: (value) {
                          validateInput();
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () => updatePercentage(
                        (int.tryParse(percentageController.text) ?? initialValue) + 5
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
                  final percentage = int.tryParse(percentageController.text) ?? initialValue;
                  Navigator.pop(context);
                  _onTimingChanged(percentage, imageIndex);
                } : null,
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageList() {
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
            
            // 현재 이미지의 타이밍 정보 확인
            int? currentPercentage;
            for (final entry in _imageTimings.entries) {
              if (entry.value == index) {
                currentPercentage = entry.key;
                break;
              }
            }
            
            // 배경색 설정
            final backgroundColor = currentPercentage != null 
                ? colors[index % colors.length].withOpacity(0.15)
                : Colors.transparent;
            
            return Card(
              key: ValueKey('image_${index}_${imagePath.hashCode}'),
              margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
              color: backgroundColor,
              elevation: currentPercentage != null ? 2 : 1,
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
                  currentPercentage != null 
                      ? _formatTimeFromPercentage(currentPercentage)
                      : '타이밍 미설정',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentPercentage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors[index % colors.length].withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${currentPercentage}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.schedule,
                        color: currentPercentage != null 
                            ? colors[index % colors.length]
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: () => _showTimingDialog(index),
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
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                labelText: '습관 이름',
                hintText: '습관의 이름을 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                  vertical: AppConstants.smallPadding,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '습관 이름을 입력해주세요.';
                }
                return null;
              },
              onTap: () {
                if (!_isNameFieldTouched) {
                  setState(() {
                    _nameController.clear();
                    _isNameFieldTouched = true;
                  });
                }
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
            
            // 타이밍 설정 박스 (이미지 선택보다 먼저)
            if (_selectedImages.isNotEmpty) ...[
              PhotoTimingBox(
                images: _selectedImages,
                imageTimings: _imageTimings,
                onTimingChanged: _onTimingChanged,
              ),
              const SizedBox(height: AppConstants.defaultPadding),
            ],
            
            // 이미지 선택 (타이밍 게이지 아래로 이동)
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
                      _buildImageList(),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppConstants.defaultPadding),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveHabit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
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