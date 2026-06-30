import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

// Registered in main.dart during controller init; set by DeleteAccountScreen
void Function(String)? deleteResultCallback;

class DeleteAccountScreen extends StatefulWidget {
  final WebViewController controller;
  final VoidCallback? onDeleted;
  const DeleteAccountScreen({super.key, required this.controller, this.onDeleted});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    deleteResultCallback = _handleDeleteResult;
  }

  @override
  void dispose() {
    deleteResultCallback = null;
    super.dispose();
  }

  Future<void> _handleDeleteResult(String message) async {
    final data = jsonDecode(message);
    debugPrint('Delete result: $message');
    setState(() => _isDeleting = false);
    if (data['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await widget.controller.loadRequest(
        Uri.parse('https://www.elearningfrcpath.com/login'),
      );
      widget.onDeleted?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account deleted successfully ✅'),
              backgroundColor: Color(0xFF2E7D32)),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Failed to delete.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    await widget.controller.runJavaScript('''
      fetch('https://www.elearningfrcpath.com/delete-account', {
        method: 'POST',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'secret=elearning_delete_2026',
        credentials: 'include'
      })
      .then(r => r.json())
      .then(data => DeleteResult.postMessage(JSON.stringify(data)))
      .catch(e => DeleteResult.postMessage(JSON.stringify({success: false, message: e.toString()})));
    ''');
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Delete Account', style: TextStyle(color: Colors.red)),
        ]),
        content: const Text(
          'This action is permanent and cannot be undone.\n\n'
          'All your data including:\n'
          '• Course purchases\n'
          '• Study progress\n'
          '• Bookmarks\n\n'
          'will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Yes, Delete My Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Column(children: [
                Icon(Icons.delete_forever, color: Colors.red, size: 48),
                SizedBox(height: 12),
                Text('Delete Your Account',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                SizedBox(height: 8),
                Text(
                  'This will permanently delete your account and all associated data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('What will be deleted:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...[
              'Your account and profile information',
              'Access to all purchased courses',
              'Study progress and history',
              'Bookmarks and reading list',
              'All personal data stored on our servers',
            ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const Icon(Icons.close, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(item,
                            style: const TextStyle(fontSize: 14))),
                  ]),
                )),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'If you have purchased courses, you will lose access to them. '
                      'This cannot be reversed. Contact support before deleting if you have concerns.',
                      style: TextStyle(fontSize: 13, color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.support_agent),
              label: const Text('Contact Support Instead'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isDeleting ? null : _showConfirmDialog,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.delete_forever),
              label: Text(_isDeleting ? 'Deleting...' : 'Delete My Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
