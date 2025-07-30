class AppConstants {
  // 앱 기본 정보
  static const String appName = 'Habit Reminder';
  static const String appVersion = '1.0.0';
  
  // 데이터베이스 관련
  static const String habitBoxName = 'habits';
  static const String habitDataKey = 'habit_data';
  
  // 위젯 관련
  static const String widgetChannelName = 'habit_reminder_widget';
  static const String widgetAndroidName = 'HabitReminderWidget';
  static const String widgetIOSName = 'HabitReminderWidget';
  static const String appGroupId = 'group.com.example.habit_reminder';
  
  // 알림 관련
  static const String notificationChannelId = 'habit_reminder_channel';
  static const String notificationChannelName = 'Habit Reminder';
  static const String notificationChannelDescription = '습관 리마인더 알림';
  
  // 시간 간격 옵션 (초 단위)
  static const List<int> timeIntervals = [
    30,    // 30초
    60,    // 1분
    300,   // 5분
    600,   // 10분
    1800,  // 30분
    3600,  // 1시간
    7200,  // 2시간
    14400, // 4시간
    28800, // 8시간
    86400, // 24시간
  ];
  
  // 기본 시간 간격
  static const int defaultIntervalSeconds = 30;
  
  // 이미지 관련
  static const int maxImageCount = 10;
  static const int maxImageSize = 1024; // 픽셀
  static const int imageQuality = 85;
  
  // UI 관련
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  static const int primaryColorValue = 0xFF2196F3;
  
  // 애니메이션 관련
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  
  // 색상
  static const int successColorValue = 0xFF4CAF50;
  static const int errorColorValue = 0xFFF44336;
  static const int warningColorValue = 0xFFFF9800;
  static const int infoColorValue = 0xFF2196F3;
  
  // 텍스트 스타일
  static const double titleFontSize = 24.0;
  static const double subtitleFontSize = 18.0;
  static const double bodyFontSize = 16.0;
  static const double captionFontSize = 14.0;
  
  // 습관 카테고리
  static const List<String> habitCategories = [
    '건강',
    '학습',
    '생산성',
    '정신 건강',
    '운동',
    '기타',
  ];
  
  // 프리셋 이미지 경로
  static const List<String> presetImagePaths = [
    'assets/images/preset_smile_1.jpg',
    'assets/images/preset_smile_2.jpg',
    'assets/images/preset_water_1.jpg',
    'assets/images/preset_water_2.jpg',
    'assets/images/preset_exercise_1.jpg',
    'assets/images/preset_exercise_2.jpg',
  ];
  
  // 설정 키
  static const String settingsKeyTheme = 'theme_mode';
  static const String settingsKeyNotifications = 'notifications_enabled';
  static const String settingsKeyVibration = 'vibration_enabled';
  static const String settingsKeySound = 'sound_enabled';
  
  // 오류 메시지
  static const String errorNoImagesSelected = '최소 하나의 이미지를 선택해주세요.';
  static const String errorInvalidHabitName = '습관 이름을 입력해주세요.';
  static const String errorInvalidInterval = '유효한 시간 간격을 선택해주세요.';
  static const String errorImageLoadFailed = '이미지 로드에 실패했습니다.';
  static const String errorSaveFailed = '저장에 실패했습니다.';
  static const String errorDeleteFailed = '삭제에 실패했습니다.';
  static const String errorNetworkFailed = '네트워크 연결을 확인해주세요.';
  
  // 성공 메시지
  static const String successHabitAdded = '습관이 추가되었습니다.';
  static const String successHabitCreated = '습관이 생성되었습니다.';
  static const String successHabitUpdated = '습관이 수정되었습니다.';
  static const String successHabitDeleted = '습관이 삭제되었습니다.';
  static const String successHabitActivated = '습관이 활성화되었습니다.';
  static const String successHabitDeactivated = '습관이 비활성화되었습니다.';
  static const String successDataBackedUp = '데이터가 백업되었습니다.';
  static const String successDataRestored = '데이터가 복원되었습니다.';
  
  // 가이드 메시지
  static const String guideSelectImages = '습관 형성에 도움이 되는 이미지를 선택해주세요.';
  static const String guideSetInterval = '이미지가 변경되는 시간 간격을 설정해주세요.';
  static const String guideAddWidget = '홈 화면에 위젯을 추가하여 습관을 더 쉽게 관리하세요.';
  static const String guideActiveHabits = '활성화된 습관만 위젯에 표시됩니다.';
  
  // 위젯 관련 메시지
  static const String widgetClickMessage = '습관이 리셋되었습니다!';
  static const String widgetUpdateMessage = '위젯이 업데이트되었습니다.';
  static const String widgetNoActiveHabits = '활성 습관이 없어 위젯을 사용할 수 없습니다.';
} 