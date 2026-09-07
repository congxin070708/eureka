import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服务
/// 用于复习到期提醒、签到提醒等
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// 初始化通知插件
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// 立即发送一条通知
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'eureka_review',
      '复习提醒',
      channelDescription: '遗忘曲线复习到期通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(id, title, body, details);
  }

  /// 安排每日定时提醒(复习提醒)
  /// hour: 0-23, minute: 0-59
  static Future<void> scheduleDailyReviewReminder({
    int hour = 20,
    int minute = 0,
  }) async {
    if (!_initialized) await init();

    await _plugin.cancel(0); // 取消之前的定时

    await _plugin.zonedSchedule(
      0,
      '📚 复习时间到',
      '点击打开 Eureka, 完成今日复习',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'eureka_review',
          '复习提醒',
          channelDescription: '遗忘曲线复习到期通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 取消所有定时通知
  static Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }

  /// 计算下一个指定时间点
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// 检查通知权限(iOS)
  static Future<bool> requestPermissions() async {
    if (!_initialized) await init();
    if (await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false) {
      return true;
    }
    return true; // Android 默认有权限
  }
}
