import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  bool _reminderEnabled = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reminderEnabled = prefs.getBool('reminder_enabled') ?? false;
      final hour = prefs.getInt('reminder_hour') ?? 9;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', _reminderEnabled);
    await prefs.setInt('reminder_hour', _selectedTime.hour);
    await prefs.setInt('reminder_minute', _selectedTime.minute);
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() => _reminderEnabled = value);
    await _saveSettings();
    if (value) {
      try {
        await NotificationService.scheduleDailyReminder(_selectedTime);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder set for ${_selectedTime.format(context)} daily ✅'),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not schedule notification: $e')),
          );
        }
      }
    } else {
      await NotificationService.cancelReminder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder cancelled')),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
      await _saveSettings();
      if (_reminderEnabled) {
        try {
          await NotificationService.scheduleDailyReminder(_selectedTime);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Reminder', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text('📚', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 8),
                  Text('Daily Study Reminder',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32))),
                  SizedBox(height: 4),
                  Text('Get daily reminders to keep your FRCPath prep on track',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enable Daily Reminder',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('Receive a daily study notification',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Switch(
                    value: _reminderEnabled,
                    onChanged: _toggleReminder,
                    activeColor: const Color(0xFF2E7D32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Time picker
            GestureDetector(
              onTap: _reminderEnabled ? _pickTime : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _reminderEnabled
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: _reminderEnabled ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reminder Time',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(_reminderEnabled ? 'Tap to change time' : 'Enable reminder first',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(_selectedTime.format(context),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _reminderEnabled
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey)),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time,
                            color: _reminderEnabled
                                ? const Color(0xFF2E7D32)
                                : Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Info
            const Text('📌 Study Tips',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...[
              'Reminders rotate daily with motivational tips',
              'Best study time: morning (7–9 AM) or evening (7–9 PM)',
              'Consistent daily study beats last-minute cramming',
            ].map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF2E7D32))),
                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
