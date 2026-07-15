import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Handles the three optional daily "log your spending" reminders.
///
/// Settings are persisted in [SharedPreferences]; the actual OS-level schedule
/// is (re)built from those settings every time something changes and once on
/// app start (which also re-arms reminders after a reboot).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'daily_reminders';
  static const _channelName = 'Daily reminders';
  static const _channelDesc = 'Reminders to log your daily transactions.';

  // SharedPreferences keys.
  static const _kEnabled = 'notif_enabled';
  static const _kMinutesPrefix = 'notif_minutes_'; // + index 0..2

  /// Default fire times: 12:00, 18:00, 22:00 (minutes since midnight).
  static const List<int> defaultMinutes = [720, 1080, 1320];

  /// Three slightly varied bodies so repeated reminders feel less robotic.
  static const List<String> _bodies = [
    "Log today's spending so your balances stay accurate.",
    'Quick check-in: added every expense and income yet?',
    'Wrap up the day — record any transactions you missed.',
  ];

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Notifications only make sense on Android & iOS.
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // ─────────────────────────── init ───────────────────────────
  Future<void> init() async {
    if (!_supported || _initialized) return;

    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Fall back to UTC if the device timezone can't be resolved.
    }

    const androidInit = AndroidInitializationSettings('ic_stat_finlytic');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  // ─────────────────────────── permissions ───────────────────────────
  /// Requests OS permission to post notifications. Returns true if granted.
  Future<bool> requestPermissions() async {
    if (!_supported) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true; // older Android versions don't gate this
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  // ─────────────────────────── settings ───────────────────────────
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  /// Reads the three configured reminder times.
  Future<List<TimeOfDay>> times() async {
    final prefs = await SharedPreferences.getInstance();
    return List.generate(3, (i) {
      final mins = prefs.getInt('$_kMinutesPrefix$i') ?? defaultMinutes[i];
      return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
    });
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await applySchedule();
  }

  Future<void> setTime(int index, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_kMinutesPrefix$index', time.hour * 60 + time.minute);
    await applySchedule();
  }

  // ─────────────────────────── scheduling ───────────────────────────
  /// Cancels all reminders and, if enabled, re-schedules the three daily ones.
  Future<void> applySchedule() async {
    if (!_supported) return;
    if (!_initialized) await init();

    await _plugin.cancelAll();
    if (!await isEnabled()) return;

    final granted = await requestPermissions();
    if (!granted) return;

    final reminderTimes = await times();
    for (var i = 0; i < reminderTimes.length; i++) {
      await _scheduleDaily(
        1001 + i,
        '💰 Finlytic reminder',
        _bodies[i % _bodies.length],
        _nextInstanceOf(reminderTimes[i]),
      );
    }
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_finlytic',
      color: Color(0xFFD97757), // terra brand accent
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Schedules one daily-repeating reminder. Prefers an exact alarm (reliable
  /// on modern Android — the app declares USE_EXACT_ALARM); if the OS refuses
  /// exact alarms it falls back to an inexact one instead of failing silently.
  Future<void> _scheduleDaily(
      int id, String title, String body, tz.TZDateTime when) async {
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          _details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time, // repeat daily
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Fires a notification immediately so the user can confirm delivery works.
  /// Throws a readable message when notifications are blocked at the OS level.
  Future<void> showTest() async {
    if (!_supported) throw 'Notifications are only available on a phone.';
    if (!_initialized) await init();
    final granted = await requestPermissions();
    if (!granted) {
      throw 'Notifications are blocked. Enable them in system settings.';
    }
    await _plugin.show(
      9999,
      '💰 Finlytic',
      'Test notification — reminders are working. 🎉',
      _details,
    );
  }

  /// The next [tz.TZDateTime] at the given wall-clock time (today or tomorrow).
  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
