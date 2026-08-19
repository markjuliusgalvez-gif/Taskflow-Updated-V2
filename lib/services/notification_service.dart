import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    final status = await Permission.notification.request();
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<void> scheduleDeadlineReminder({
    required String assignmentId,
    required String title,
    required DateTime deadline,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, deadline.year, deadline.month,
        deadline.day, deadline.hour, deadline.minute);

    if (scheduled.isBefore(now)) {
      scheduled = now.add(const Duration(minutes: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'assignment_deadlines',
      'Assignment Deadlines',
      channelDescription: 'Reminders for assignment deadlines',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      assignmentId.hashCode,
      'Assignment Deadline',
      '"$title" is due now.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> cancelReminder(String assignmentId) async {
    await _plugin.cancel(assignmentId.hashCode);
  }
}
