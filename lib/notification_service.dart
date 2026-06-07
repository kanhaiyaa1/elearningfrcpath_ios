import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _taskName = 'studyReminderTask';
const _taskKey = 'studyReminder';
const _tipTaskName = 'studyTipTask';
const _tipTaskKey = 'studyTip';

const List<String> _studyReminders = [
  "Time to study FRCPath! 📚 Consistency is key.",
  "Daily revision keeps FRCPath concepts fresh! 🧠",
  "Study smart today — your FRCPath success awaits! 🏆",
  "Don't forget your NEET-SS prep today! 💪",
  "10 minutes of pathology a day keeps failure away! 🔬",
  "Your future self will thank you for studying today! ⭐",
  "FRCPath mastery requires daily practice. Start now! 📖",
  "Time for your daily dose of pathology! 🧬",
  "Small steps daily lead to big results. Study now! 🎯",
  "Your FRCPath exam prep starts with today's session! ✅",
];

const List<String> _studyTips = [
  "🔬 Tip: Focus on common histological patterns — they appear repeatedly in FRCPath Part 1.",
  "🧠 Tip: Use mnemonics for TNM staging — easier to recall under exam pressure.",
  "📖 Tip: Read one pathology case study daily to sharpen diagnostic thinking.",
  "💡 Tip: Immunohistochemistry markers are high-yield for FRCPath Part 2.",
  "🎯 Tip: Practice MCQs in timed conditions to simulate exam pressure.",
  "🔍 Tip: Understand the pathogenesis, not just the diagnosis — examiners love 'why'.",
  "📝 Tip: Write short notes after each topic — active recall beats passive reading.",
  "⚡ Tip: Robbins & Cotran is your bible — know the key tables by heart.",
  "🏆 Tip: FRCPath Part 1 is 90% histopathology — prioritize it.",
  "🧬 Tip: Learn molecular pathology basics — it's increasingly tested in FRCPath.",
  "💪 Tip: Revise each topic at least 3 times using spaced repetition.",
  "🔬 Tip: Inflammation and repair questions are almost guaranteed in FRCPath.",
  "📊 Tip: Understand grading vs staging — examiners test this distinction.",
  "🎓 Tip: Past FRCPath papers are gold — solve at least 5 years of past papers.",
  "⏱️ Tip: Time management in FRCPath is crucial — practice under exam conditions.",
  "🌟 Tip: Neoplasia is the most tested topic — understand benign vs malignant criteria.",
  "📚 Tip: Cellular adaptations (hypertrophy, hyperplasia, atrophy) are high yield.",
  "🔭 Tip: Electron microscopy findings are tested — know key ultrastructural patterns.",
  "💊 Tip: Drug-induced pathology is a common FRCPath question area.",
  "🧪 Tip: Special stains — know which stain. Congo Red, PAS, Masson Trichrome.",
  "🏥 Tip: Clinical correlation questions are increasing — bridge basic and clinical.",
  "📐 Tip: Morphometry and quantitative pathology basics are worth knowing.",
  "🦠 Tip: Infectious disease pathology — granuloma formation is heavily tested.",
  "❤️ Tip: Cardiovascular pathology — MI changes by time period is classic FRCPath.",
  "🫁 Tip: Lung pathology — know the pneumoconioses and their specific dust exposures.",
  "🧫 Tip: Cell injury mechanisms — free radicals, reperfusion injury, apoptosis vs necrosis.",
  "🔐 Tip: Genetic pathology — autosomal dominant vs recessive conditions are tested.",
  "🌊 Tip: Fluid and hemodynamic disorders — edema types are commonly tested.",
  "🎯 Tip: Endocrine pathology — pheochromocytoma and MEN syndromes are FRCPath favorites.",
  "🏁 Tip: You've got this! Every study session brings you closer to FRCPath success! 💪",
];

// WorkManager callback — Android only
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: androidSettings));

    await plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'study_reminder', 'Study Reminders', importance: Importance.max));

    await plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'study_tips', 'Study Tips', importance: Importance.defaultImportance));

    if (task == _taskKey) {
      await plugin.show(
        0,
        'eLearningFRCPath 📚',
        _studyReminders[DateTime.now().day % _studyReminders.length],
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_reminder', 'Study Reminders',
            importance: Importance.max, priority: Priority.high,
            playSound: true, enableVibration: true,
          ),
        ),
      );
      // Reschedule for tomorrow
      await Workmanager().registerOneOffTask(
        _taskKey, _taskName,
        initialDelay: const Duration(hours: 24),
        constraints: Constraints(networkType: NetworkType.notRequired),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } else if (task == _tipTaskKey) {
      final prefs = await SharedPreferences.getInstance();
      final tipIndex = prefs.getInt('tip_index') ?? 0;
      await prefs.setInt('tip_index', (tipIndex + 1) % _studyTips.length);

      await plugin.show(
        1,
        'FRCPath Study Tip of the Day 🎓',
        _studyTips[tipIndex],
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_tips', 'Study Tips',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
      // Reschedule tip for tomorrow 8 AM
      final now = DateTime.now();
      var next8am = DateTime(now.year, now.month, now.day, 8, 0);
      if (next8am.isBefore(now)) next8am = next8am.add(const Duration(days: 1));
      await Workmanager().registerOneOffTask(
        _tipTaskKey, _tipTaskName,
        initialDelay: next8am.difference(now),
        constraints: Constraints(networkType: NetworkType.notRequired),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }

    return Future.value(true);
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
        'study_reminder', 'Study Reminders',
        description: 'Daily study reminder notifications',
        importance: Importance.max, playSound: true, enableVibration: true,
      ));
      await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
        'study_tips', 'Study Tips',
        description: 'Daily FRCPath study tips',
        importance: Importance.defaultImportance,
      ));
      await androidPlugin?.requestNotificationsPermission();
      await Workmanager().initialize(callbackDispatcher);
      // Schedule daily tip at 8 AM via WorkManager
      await _scheduleTipAndroid();
    } else {
      // iOS: schedule daily tip via zonedSchedule
      await _scheduleDailyTipIOS();
    }
  }

  // ── Study Reminder (user-set time) ────────────────────────────────────────

  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    if (Platform.isAndroid) {
      await _scheduleAndroid(time);
    } else {
      await _scheduleIOS(time);
    }
  }

  static Future<void> _scheduleAndroid(TimeOfDay time) async {
    await Workmanager().cancelByUniqueName(_taskKey);
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    await Workmanager().registerOneOffTask(
      _taskKey, _taskName,
      initialDelay: scheduled.difference(now),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> _scheduleIOS(TimeOfDay time) async {
    try { await _plugin.cancel(0); } catch (_) {}
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      0,
      'eLearningFRCPath 📚',
      _studyReminders[DateTime.now().day % _studyReminders.length],
      scheduled,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelReminder() async {
    if (Platform.isAndroid) {
      await Workmanager().cancelByUniqueName(_taskKey);
    } else {
      try { await _plugin.cancel(0); } catch (_) {}
    }
  }

  // ── Daily Study Tip (8:00 AM) ─────────────────────────────────────────────

  static Future<void> _scheduleTipAndroid() async {
    final now = DateTime.now();
    var next8am = DateTime(now.year, now.month, now.day, 8, 0);
    if (next8am.isBefore(now)) next8am = next8am.add(const Duration(days: 1));
    await Workmanager().registerOneOffTask(
      _tipTaskKey, _tipTaskName,
      initialDelay: next8am.difference(now),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  static Future<void> _scheduleDailyTipIOS() async {
    try { await _plugin.cancel(1); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final tipIndex = prefs.getInt('tip_index') ?? 0;
    await prefs.setInt('tip_index', (tipIndex + 1) % _studyTips.length);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      1,
      'FRCPath Study Tip of the Day 🎓',
      _studyTips[tipIndex],
      scheduled,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: false, presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
