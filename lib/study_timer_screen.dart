import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TimerMode { study, shortBreak, longBreak }

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});
  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen>
    with TickerProviderStateMixin {
  TimerMode _mode = TimerMode.study;
  Timer? _timer;
  bool _isRunning = false;
  int _secondsLeft = 25 * 60;
  int _completedSessions = 0;
  late AnimationController _animController;

  final Map<TimerMode, int> _durations = {
    TimerMode.study: 25 * 60,
    TimerMode.shortBreak: 5 * 60,
    TimerMode.longBreak: 15 * 60,
  };

  final Map<TimerMode, String> _labels = {
    TimerMode.study: 'Study Session',
    TimerMode.shortBreak: 'Short Break',
    TimerMode.longBreak: 'Long Break',
  };

  final Map<TimerMode, Color> _colors = {
    TimerMode.study: const Color(0xFF2E7D32),
    TimerMode.shortBreak: const Color(0xFF1565C0),
    TimerMode.longBreak: const Color(0xFF6A1B9A),
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _durations[_mode]!),
    );
    _secondsLeft = _durations[_mode]!;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _switchMode(TimerMode mode) {
    if (_isRunning) _stopTimer();
    setState(() {
      _mode = mode;
      _secondsLeft = _durations[mode]!;
    });
    _animController.reset();
    _animController.duration = Duration(seconds: _durations[mode]!);
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _animController.forward(from: _animController.value);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) {
        _onTimerComplete();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _animController.stop();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _stopTimer();
    setState(() => _secondsLeft = _durations[_mode]!);
    _animController.reset();
  }

  void _onTimerComplete() async {
    _timer?.cancel();
    _animController.reset();
    HapticFeedback.heavyImpact();

    if (_mode == TimerMode.study) {
      setState(() => _completedSessions++);
      final prefs = await SharedPreferences.getInstance();
      final sessions = (prefs.getInt('total_sessions') ?? 0) + 1;
      final minutes = (prefs.getInt('total_study_minutes') ?? 0) + 25;
      await prefs.setInt('total_sessions', sessions);
      await prefs.setInt('total_study_minutes', minutes);
    }

    setState(() {
      _isRunning = false;
      _secondsLeft = _durations[_mode]!;
    });
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    final isStudy = _mode == TimerMode.study;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isStudy ? '🎉 Session Complete!' : '⏰ Break Over!'),
        content: Text(isStudy
            ? 'Great work! You completed a study session.\nTotal sessions: $_completedSessions'
            : 'Ready to get back to studying?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _switchMode(isStudy ? TimerMode.shortBreak : TimerMode.study);
            },
            child: Text(isStudy ? 'Take Break' : 'Start Studying'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress => _secondsLeft / _durations[_mode]!;

  Color get _currentColor => _colors[_mode]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Study Timer', style: TextStyle(color: Colors.white)),
        backgroundColor: _currentColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Mode selector
          Container(
            color: _currentColor,
            padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: TimerMode.values.map((mode) {
                final selected = _mode == mode;
                return GestureDetector(
                  onTap: () => _switchMode(mode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Text(
                      mode == TimerMode.study
                          ? 'Study'
                          : mode == TimerMode.shortBreak
                              ? 'Short Break'
                              : 'Long Break',
                      style: TextStyle(
                        color: selected ? _currentColor : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 48),

          // Timer circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 260,
                height: 260,
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (_, _) => CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(_currentColor),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(_secondsLeft),
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: _currentColor,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[_mode]!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 48),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _resetTimer,
                icon: const Icon(Icons.replay_rounded),
                iconSize: 36,
                color: Colors.grey,
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _isRunning ? _stopTimer : _startTimer,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _currentColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: _onTimerComplete,
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 36,
                color: Colors.grey,
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Sessions counter
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('$_completedSessions', 'Sessions\nCompleted', Icons.check_circle_outline),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _statItem(
                  '${_completedSessions * 25} min',
                  'Total Study\nTime',
                  Icons.timer_outlined,
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                _statItem(
                  '${_completedSessions >= 4 ? _completedSessions ~/ 4 : 0}',
                  'Long Breaks\nEarned',
                  Icons.coffee_outlined,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '💡 After 4 study sessions, take a long break to maximize retention.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
