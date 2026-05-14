import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _url = 'https://elearningfrcpath.com/';
const _host = 'elearningfrcpath.com';

// JavaScript injected after every page load.
// Detects a pull-down gesture at scrollY=0 and notifies Flutter.
const _pullToRefreshJs = '''
(function() {
  if (window.__flutterPTR) return;
  window.__flutterPTR = true;
  var startY = 0, pulling = false;
  document.addEventListener('touchstart', function(e) {
    startY = e.touches[0].clientY;
    pulling = false;
  }, {passive: true});
  document.addEventListener('touchmove', function(e) {
    if (window.scrollY === 0 && e.touches[0].clientY - startY > 80)
      pulling = true;
  }, {passive: true});
  document.addEventListener('touchend', function() {
    if (pulling) { pulling = false; FlutterPTR.postMessage('r'); }
  }, {passive: true});
})();
''';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eLearningFRCPath',
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

// ─── Splash ───────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(_url));

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WebViewScreen(controller: _controller),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/appIcon.png',
          width: 250,
          height: 250,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

// ─── WebView screen ───────────────────────────────────────────────────────────

class WebViewScreen extends StatefulWidget {
  final WebViewController controller;
  const WebViewScreen({super.key, required this.controller});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _setupConnectivity();
    _setupController();
    _checkIfAlreadyLoaded();
  }

  // ── Controller setup ─────────────────────────────────────────────────────────

  void _setupController() {
    // JS channel: page tells Flutter when user pulls to refresh
    widget.controller.addJavaScriptChannel(
      'FlutterPTR',
      onMessageReceived: (_) => _triggerRefresh(),
    );

    widget.controller.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (_) => setState(() => _isLoading = true),
      onPageFinished: (_) {
        setState(() => _isLoading = false);
        _inject();
      },
      onNavigationRequest: (req) {
        final uri = Uri.parse(req.url);
        if (uri.host.isEmpty || uri.host.contains(_host)) {
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    ));
  }

  void _inject() =>
      widget.controller.runJavaScript(_pullToRefreshJs);

  Future<void> _triggerRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await widget.controller.loadRequest(Uri.parse(_url));
    // loading overlay will cover; _isRefreshing resets in onPageFinished path
    if (mounted) setState(() => _isRefreshing = false);
  }

  // ── Connectivity ─────────────────────────────────────────────────────────────

  void _setupConnectivity() {
    Connectivity().checkConnectivity().then((r) {
      if (mounted) setState(() => _isOnline = _online(r));
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) {
      final on = _online(r);
      if (on && !_isOnline) {
        widget.controller.loadRequest(Uri.parse(_url));
      }
      if (mounted) setState(() => _isOnline = on);
    });
  }

  bool _online(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  // ── Pre-load detection ────────────────────────────────────────────────────────

  Future<void> _checkIfAlreadyLoaded() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    try {
      final r = await widget.controller
          .runJavaScriptReturningResult('document.readyState');
      if (mounted && (r == '"complete"' || r == 'complete')) {
        setState(() => _isLoading = false);
        _inject();
      }
    } catch (_) {}
  }

  Future<void> _onRetry() async {
    final r = await Connectivity().checkConnectivity();
    if (!mounted) return;
    final on = _online(r);
    setState(() => _isOnline = on);
    if (on) widget.controller.loadRequest(Uri.parse(_url));
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await widget.controller.canGoBack()) {
          widget.controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: _isOnline
              ? _webViewStack()
              : _NoInternetScreen(onRetry: _onRetry),
        ),
      ),
    );
  }

  Widget _webViewStack() {
    return Stack(
      children: [
        // WebView with no scroll wrapper — handles its own native scrolling
        WebViewWidget(controller: widget.controller),

        // Thin bar at top while JS-triggered pull-to-refresh is running
        if (_isRefreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: Color(0xFF1565C0),
              backgroundColor: Color(0xFFE3F2FD),
            ),
          ),

        // Full-screen loading overlay (initial / navigation loads)
        if (_isLoading)
          Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/appIcon.png',
                    width: 100,
                    height: 100,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── No-internet screen ───────────────────────────────────────────────────────

class _NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoInternetScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: Image.asset(
                'assets/appIcon.png',
                width: 80,
                height: 80,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.wifi_off_rounded, size: 60, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 16),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection\nand try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9E9E9E),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
