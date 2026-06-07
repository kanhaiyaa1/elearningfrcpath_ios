import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReadingListItem {
  final String title;
  final String url;
  final String savedAt;

  ReadingListItem({required this.title, required this.url, required this.savedAt});

  Map<String, dynamic> toJson() => {'title': title, 'url': url, 'savedAt': savedAt};

  factory ReadingListItem.fromJson(Map<String, dynamic> json) => ReadingListItem(
    title: json['title'],
    url: json['url'],
    savedAt: json['savedAt'],
  );
}

class ReadingListScreen extends StatefulWidget {
  final Function(String url) onOpenUrl;
  const ReadingListScreen({super.key, required this.onOpenUrl});

  @override
  State<ReadingListScreen> createState() => _ReadingListScreenState();
}

class _ReadingListScreenState extends State<ReadingListScreen> {
  List<ReadingListItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('reading_list') ?? [];
    setState(() {
      _items = raw.map((e) => ReadingListItem.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _remove(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _items.removeAt(index);
    await prefs.setStringList(
      'reading_list',
      _items.map((e) => jsonEncode(e.toJson())).toList(),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading List', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.menu_book_outlined, size: 72, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No saved pages yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Tap the reading list icon to save pages for later',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = _items[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.article_outlined, color: Color(0xFF2E7D32)),
                  ),
                  title: Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(item.savedAt,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _remove(i),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onOpenUrl(item.url);
                  },
                );
              },
            ),
    );
  }
}
