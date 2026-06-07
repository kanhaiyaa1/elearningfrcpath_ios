import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'biometric_service.dart';

class LockScreen extends StatefulWidget {
  final Widget nextScreen;
  const LockScreen({super.key, required this.nextScreen});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isAuthenticating = false;
  String _message = 'Authenticate to continue';
  List<BiometricType> _biometrics = [];

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
    _authenticate();
  }

  Future<void> _loadBiometrics() async {
    final biometrics = await BiometricService.getAvailableBiometrics();
    setState(() => _biometrics = biometrics);
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _message = 'Authenticating...';
    });

    final success = await BiometricService.authenticate();

    if (success) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.nextScreen),
        );
      }
    } else {
      setState(() {
        _isAuthenticating = false;
        _message = 'Authentication failed. Try again.';
      });
    }
  }

  String get _biometricIcon {
    if (_biometrics.contains(BiometricType.face)) return '👤';
    if (_biometrics.contains(BiometricType.fingerprint)) return '👆';
    return '🔒';
  }

  String get _biometricLabel {
    if (_biometrics.contains(BiometricType.face)) return 'Face ID';
    if (_biometrics.contains(BiometricType.fingerprint)) return 'Touch ID';
    return 'Biometrics';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A2F),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Image.asset('assets/appIcon.png',
                    width: 80, height: 80,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.school, size: 60, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              const Text('eLearningFRCPath',
                  style: TextStyle(color: Colors.white,
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Your FRCPath Learning Platform',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 60),

              // Biometric button
              GestureDetector(
                onTap: _isAuthenticating ? null : _authenticate,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: _isAuthenticating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_biometricIcon,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 48)),
                ),
              ),
              const SizedBox(height: 20),
              Text(_message,
                  style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isAuthenticating ? null : _authenticate,
                child: Text('Use $_biometricLabel',
                    style: const TextStyle(color: Colors.greenAccent,
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
