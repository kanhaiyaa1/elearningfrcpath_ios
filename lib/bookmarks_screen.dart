import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarksScreen extends StatefulWidget {
  final Function(String url) onOpenUrl;
  const BookmarksScreen({super.key, required this.onOpenUrl});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Map<String, String>> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookmarks') ?? [];
    setState(() {
      _bookmarks = raw.map((e) {
        final parts = e.split('|||');
        return {'title': parts[0], 'url': parts.length > 1 ? parts[1] : ''};
      }).toList();
    });
  }

  Future<void> _removeBookmark(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _bookmarks.removeAt(index);
    await prefs.setStringList(
      'bookmarks',
      _bookmarks.map((e) => '${e['title']}|||${e['url']}').toList(),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _bookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No bookmarks yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Tap the bookmark icon to save pages',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              itemCount: _bookmarks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = _bookmarks[i];
                return ListTile(
                  leading: const Icon(Icons.bookmark,
                      color: Color(0xFF2E7D32)),
                  title: Text(b['title'] ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(b['url'] ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeBookmark(i),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onOpenUrl(b['url'] ?? '');
                  },
                );
              },
            ),
    );
  }
}
