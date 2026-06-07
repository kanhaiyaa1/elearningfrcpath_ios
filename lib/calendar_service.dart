import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';

class CalendarService {
  static Future<void> addStudySession(
    BuildContext context, {
    String title = 'FRCPath Study Session',
    String description = 'Scheduled study session via eLearningFRCPath app',
    DateTime? startTime,
    int durationMinutes = 25,
  }) async {
    final start = startTime ?? DateTime.now().add(const Duration(hours: 1));
    final end = start.add(Duration(minutes: durationMinutes));

    final event = Event(
      title: title,
      description: description,
      location: 'eLearningFRCPath App',
      startDate: start,
      endDate: end,
      recurrence: Recurrence(frequency: Frequency.daily),
      allDay: false,
    );

    await Add2Calendar.addEvent2Cal(event);
  }

  static Future<void> addExamReminder(
    BuildContext context, {
    required String examName,
    required DateTime examDate,
  }) async {
    final event = Event(
      title: '📝 $examName Exam',
      description: 'Exam reminder set via eLearningFRCPath',
      startDate: examDate,
      endDate: examDate.add(const Duration(hours: 3)),
      allDay: false,
    );

    await Add2Calendar.addEvent2Cal(event);
  }
}
