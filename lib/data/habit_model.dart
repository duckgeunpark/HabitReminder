import 'package:hive/hive.dart';

part 'habit_model.g.dart';

@HiveType(typeId: 0)
class Habit extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> imagePaths;

  @HiveField(3)
  int intervalSeconds;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  int currentImageIndex;

  @HiveField(7)
  DateTime? lastResetTime;

  @HiveField(8)
  int streakCount;

  @HiveField(9)
  int totalClicks;

  @HiveField(10)
  Map<int, int> imageTimings; // 퍼센트 -> 이미지 인덱스

  Habit({
    required this.id,
    required this.name,
    required this.imagePaths,
    required this.intervalSeconds,
    required this.createdAt,
    this.isActive = true,
    this.currentImageIndex = 0,
    this.lastResetTime,
    this.streakCount = 0,
    this.totalClicks = 0,
    this.imageTimings = const {},
  });

  /// 현재 이미지 경로 가져오기
  String? getCurrentImage() {
    if (imagePaths.isEmpty) return null;
    if (currentImageIndex >= imagePaths.length) {
      currentImageIndex = 0;
    }
    return imagePaths[currentImageIndex];
  }

  /// 다음 이미지로 이동
  void nextImage() {
    if (imagePaths.isNotEmpty) {
      currentImageIndex = (currentImageIndex + 1) % imagePaths.length;
    }
  }

  /// 첫 번째 이미지로 리셋
  void resetToFirstImage() {
    currentImageIndex = 0;
  }

  /// 연속 달성 업데이트
  void updateStreak() {
    streakCount++;
    lastResetTime = DateTime.now();
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePaths': imagePaths,
      'intervalSeconds': intervalSeconds,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'currentImageIndex': currentImageIndex,
      'lastResetTime': lastResetTime?.toIso8601String(),
      'streakCount': streakCount,
      'totalClicks': totalClicks,
      'imageTimings': imageTimings,
    };
  }

  /// JSON에서 생성
  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'],
      name: json['name'],
      imagePaths: List<String>.from(json['imagePaths']),
      intervalSeconds: json['intervalSeconds'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'] ?? true,
      currentImageIndex: json['currentImageIndex'] ?? 0,
      lastResetTime: json['lastResetTime'] != null 
          ? DateTime.parse(json['lastResetTime']) 
          : null,
      streakCount: json['streakCount'] ?? 0,
      totalClicks: json['totalClicks'] ?? 0,
      imageTimings: json['imageTimings'] != null 
          ? Map<int, int>.from(json['imageTimings'])
          : const {},
    );
  }
} 