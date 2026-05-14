import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _url = 'https://elearningfrcpath.com/';
const _host = 'elearningfrcpath.com';

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

    // Start loading during splash so the page is ready (or near-ready)
    // by the time the user reaches the WebView screen.
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
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();

    _setupConnectivity();
    _setupNavigationDelegate();
    _checkIfAlreadyLoaded();
  }

  // ── Connectivity ────────────────────────────────────────────────────────────

  void _setupConnectivity() {
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() => _isOnline = _hasConnection(results));
      }
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online && !_isOnline) {
        // Came back online — reload
        widget.controller.loadRequest(Uri.parse(_url));
      }
      if (mounted) setState(() => _isOnline = online);
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  // ── Navigation delegate ─────────────────────────────────────────────────────

  void _setupNavigationDelegate() {
    widget.controller.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (_) => setState(() => _isLoading = true),
      onPageFinished: (_) => setState(() => _isLoading = false),
      onNavigationRequest: (request) {
        final uri = Uri.parse(request.url);
        // Keep internal links inside the WebView
        if (uri.host.isEmpty || uri.host.contains(_host)) {
          return NavigationDecision.navigate;
        }
        // Open external links in the device browser
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    ));
  }

  // ── Pre-load detection ──────────────────────────────────────────────────────

  Future<void> _checkIfAlreadyLoaded() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    try {
      final result = await widget.controller
          .runJavaScriptReturningResult('document.readyState');
      if (mounted && (result == '"complete"' || result == 'complete')) {
        setState(() => _isLoading = false);
      }
    } catch (_) {}
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _onRefresh() async {
    await widget.controller.loadRequest(Uri.parse(_url));
  }

  Future<void> _onRetry() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _isOnline = _hasConnection(results));
    if (_isOnline) {
      widget.controller.loadRequest(Uri.parse(_url));
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
          child: _isOnline ? _webViewStack() : _NoInternetScreen(onRetry: _onRetry),
        ),
      ),
    );
  }

  Widget _webViewStack() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF1565C0),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              child: WebViewWidget(controller: widget.controller),
            ),
          ),
        ),
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
                0,      0,      0,      1, 0,
              ]),
              child: Image.asset(
                'assets/appIcon.png',
                width: 80,
                height: 80,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.wifi_off_rounded,
              size: 60,
              color: Color(0xFFBDBDBD),
            ),
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
              style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E), height: 1.5),
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
