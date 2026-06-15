import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quiz_data.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  int _totalAttempted = 0;
  String _selectedTopic = 'All Topics';
  List<QuizQuestion> _filteredQuestions = [];
  bool _showExplanation = false;

  final List<String> _topics = [
    'All Topics',
    'Thyroid Pathology',
    'Breast Pathology',
    'Hepatobiliary Pathology',
    'Pancreatic Pathology',
    'Dermatopathology',
    'Forensic Pathology',
    'Gynecological Pathology',
    'Genitourinary Pathology',
    'Renal Pathology',
    'Hematopathology',
    'Gastrointestinal Pathology',
    'Pulmonary Pathology',
    'Molecular Pathology',
    'Neuropathology',
    'Clinical Governance',
  ];

  @override
  void initState() {
    super.initState();
    _filterQuestions();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _score = prefs.getInt('quiz_score') ?? 0;
      _totalAttempted = prefs.getInt('quiz_total') ?? 0;
    });
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quiz_score', _score);
    await prefs.setInt('quiz_total', _totalAttempted);
  }

  void _filterQuestions() {
    setState(() {
      if (_selectedTopic == 'All Topics') {
        _filteredQuestions = List.from(frcpathQuestions)..shuffle();
      } else {
        _filteredQuestions = frcpathQuestions.where((q) => q.topic == _selectedTopic).toList()..shuffle();
      }
      _currentIndex = 0;
      _selectedAnswer = null;
      _answered = false;
      _showExplanation = false;
    });
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      _totalAttempted++;
      if (index == _filteredQuestions[_currentIndex].correctIndex) {
        _score++;
        HapticFeedback.heavyImpact();
      }
    });
    _saveStats();
  }

  void _nextQuestion() {
    if (_currentIndex < _filteredQuestions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
        _showExplanation = false;
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quiz Complete! 🎉',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_score / ${_filteredQuestions.length}',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32))),
            const SizedBox(height: 8),
            Text('${(_score / _filteredQuestions.length * 100).toStringAsFixed(0)}% Score',
                style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 16),
            Text(
              _score >= _filteredQuestions.length * 0.8
                  ? 'Excellent! You\'re well prepared! 🏆'
                  : _score >= _filteredQuestions.length * 0.6
                  ? 'Good effort! Keep revising! 📚'
                  : 'Keep practicing! You\'ll get there! 💪',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _filterQuestions();
            },
            child: const Text('Retry'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Color _getOptionColor(int index) {
    if (!_answered) return Colors.white;
    if (index == _filteredQuestions[_currentIndex].correctIndex) {
      return const Color(0xFFE8F5E9);
    }
    if (index == _selectedAnswer) return const Color(0xFFFFEBEE);
    return Colors.white;
  }

  Color _getOptionBorder(int index) {
    if (!_answered) return Colors.grey.shade300;
    if (index == _filteredQuestions[_currentIndex].correctIndex) {
      return const Color(0xFF2E7D32);
    }
    if (index == _selectedAnswer) return Colors.red;
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredQuestions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No questions available')),
      );
    }

    final q = _filteredQuestions[_currentIndex];
    final progress = (_currentIndex + 1) / _filteredQuestions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('FRCPath MCQ Quiz',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('$_score/$_totalAttempted',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Topic selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTopic,
                isExpanded: true,
                items: _topics.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t, style: const TextStyle(fontSize: 14)),
                )).toList(),
                onChanged: (val) {
                  setState(() => _selectedTopic = val!);
                  _filterQuestions();
                },
              ),
            ),
          ),

          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            minHeight: 4,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question counter + topic
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_currentIndex + 1} / ${_filteredQuestions.length}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(q.topic,
                            style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Question
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Text(q.question,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.5)),
                  ),
                  const SizedBox(height: 16),

                  // Options
                  ...List.generate(q.options.length, (i) {
                    return GestureDetector(
                      onTap: () => _selectAnswer(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getOptionColor(i),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getOptionBorder(i), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _answered
                                    ? i == q.correctIndex
                                    ? const Color(0xFF2E7D32)
                                    : i == _selectedAnswer
                                    ? Colors.red
                                    : Colors.grey.shade200
                                    : Colors.grey.shade200,
                              ),
                              child: Center(
                                child: _answered
                                    ? Icon(
                                  i == q.correctIndex
                                      ? Icons.check
                                      : i == _selectedAnswer
                                      ? Icons.close
                                      : null,
                                  color: Colors.white,
                                  size: 16,
                                )
                                    : Text(
                                  String.fromCharCode(65 + i),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(q.options[i],
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _answered &&
                                          i == q.correctIndex
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Explanation
                  if (_answered && q.explanation != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showExplanation = !_showExplanation),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('💡 Explanation',
                                    style: TextStyle(fontWeight: FontWeight.bold,
                                        color: Color(0xFFE65100))),
                                Icon(_showExplanation
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                    color: const Color(0xFFE65100)),
                              ],
                            ),
                            if (_showExplanation) ...[
                              const SizedBox(height: 8),
                              Text(q.explanation!,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.brown, height: 1.5)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Next button
                  if (_answered)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _currentIndex < _filteredQuestions.length - 1
                              ? 'Next Question →'
                              : 'See Results',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
