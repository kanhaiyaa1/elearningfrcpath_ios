import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'biometric_service.dart';
import 'delete_account_screen.dart';

class BiometricSettingsScreen extends StatefulWidget {
  final WebViewController controller;
  const BiometricSettingsScreen({super.key, required this.controller});
  @override
  State<BiometricSettingsScreen> createState() => _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  bool _isAvailable = false;
  bool _isEnabled = false;
  String _biometricLabel = 'Biometrics';
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    debugPrint('Biometric screen user_id: $userId');
    setState(() => _isLoggedIn = userId != null && userId > 0);
  }

  Future<void> _load() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    final biometrics = await BiometricService.getAvailableBiometrics();

    String label = 'Biometrics';
    if (biometrics.contains(BiometricType.face)) label = 'Face ID';
    if (biometrics.contains(BiometricType.fingerprint)) label = 'Touch ID';

    setState(() {
      _isAvailable = available;
      _isEnabled = enabled;
      _biometricLabel = label;
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      final success = await BiometricService.authenticate();
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed')),
          );
        }
        return;
      }
    }
    await BiometricService.setBiometricEnabled(value);
    setState(() => _isEnabled = value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? '$_biometricLabel lock enabled ✅'
              : '$_biometricLabel lock disabled'),
          backgroundColor: value ? const Color(0xFF2E7D32) : Colors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Text(
                  _biometricLabel == 'Face ID' ? '👤' : '👆',
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text('$_biometricLabel Lock',
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                const SizedBox(height: 4),
                Text('Secure your app with $_biometricLabel',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 24),

            if (_isAvailable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Enable $_biometricLabel Lock',
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      Text('Require authentication on app open',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                    Switch(
                      value: _isEnabled,
                      onChanged: _toggle,
                      activeThumbColor: const Color(0xFF2E7D32),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Biometric authentication is not available on this device.',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ]),
              ),
            if (_isLoggedIn) ...[
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => DeleteAccountScreen(
                        controller: widget.controller,
                      ))),
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Delete My Account',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
