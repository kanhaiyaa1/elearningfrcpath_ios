import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  final Function(String url) onOpenUrl;
  const DashboardScreen({super.key, required this.onOpenUrl});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _bookmarkCount = 0;
  int _readingListCount = 0;
  int _studySessions = 0;
  int _studyMinutes = 0;
  int _pagesVisited = 0;
  List<Map<String, String>> _recentBookmarks = [];
  List<Map<String, String>> _recentReadingList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Bookmarks
    final bookmarks = prefs.getStringList('bookmarks') ?? [];
    final recentBookmarks = bookmarks.take(3).map((e) {
      final parts = e.split('|||');
      return {'title': parts[0], 'url': parts.length > 1 ? parts[1] : e};
    }).toList();

    // Reading list
    final readingList = prefs.getStringList('reading_list') ?? [];
    final recentReading = readingList.take(3).map((e) {
      final item = jsonDecode(e) as Map<String, dynamic>;
      return {'title': item['title'] as String, 'url': item['url'] as String};
    }).toList();

    // Study stats
    final sessions = prefs.getInt('total_sessions') ?? 0;
    final minutes = prefs.getInt('total_study_minutes') ?? 0;
    final pages = prefs.getInt('pages_visited') ?? 0;

    setState(() {
      _bookmarkCount = bookmarks.length;
      _readingListCount = readingList.length;
      _studySessions = sessions;
      _studyMinutes = minutes;
      _pagesVisited = pages;
      _recentBookmarks = recentBookmarks;
      _recentReadingList = recentReading;
    });
  }

  String _formatStudyTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF2E7D32),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome back! 👋',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Your FRCPath Progress',
                        style: TextStyle(color: Colors.white,
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _miniStat('$_studySessions', 'Sessions'),
                        const SizedBox(width: 24),
                        _miniStat(_formatStudyTime(_studyMinutes), 'Studied'),
                        const SizedBox(width: 24),
                        _miniStat('$_pagesVisited', 'Pages Read'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Stats grid
              const Text('Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _statCard('📚', 'Bookmarks', '$_bookmarkCount saved',
                      const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
                  _statCard('📖', 'Reading List', '$_readingListCount pages',
                      const Color(0xFFF3E5F5), const Color(0xFF6A1B9A)),
                  _statCard('⏱️', 'Study Sessions', '$_studySessions completed',
                      const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                  _statCard('🔬', 'Pages Visited', '$_pagesVisited explored',
                      const Color(0xFFFFF3E0), const Color(0xFFE65100)),
                ],
              ),
              const SizedBox(height: 20),

              // Recent bookmarks
              if (_recentBookmarks.isNotEmpty) ...[
                _sectionHeader('Recent Bookmarks', Icons.bookmark_outlined),
                const SizedBox(height: 8),
                ..._recentBookmarks.map((item) => _urlCard(
                  item['title']!,
                  item['url']!,
                  Icons.bookmark,
                  const Color(0xFF1565C0),
                )),
                const SizedBox(height: 20),
              ],

              // Recent reading list
              if (_recentReadingList.isNotEmpty) ...[
                _sectionHeader('Reading List', Icons.menu_book_outlined),
                const SizedBox(height: 8),
                ..._recentReadingList.map((item) => _urlCard(
                  item['title']!,
                  item['url']!,
                  Icons.article_outlined,
                  const Color(0xFF6A1B9A),
                )),
                const SizedBox(height: 20),
              ],

              // Study tip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💡', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Study Tip',
                              style: TextStyle(fontWeight: FontWeight.bold,
                                  color: Color(0xFFE65100))),
                          SizedBox(height: 4),
                          Text(
                            'FRCPath Part 1 requires consistent daily revision. '
                            'Aim for at least 4 Pomodoro sessions per day for best results.',
                            style: TextStyle(fontSize: 13, color: Colors.brown),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _statCard(String emoji, String title, String subtitle,
      Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: textColor, fontSize: 14)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _urlCard(String title, String url, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.onOpenUrl(url);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
