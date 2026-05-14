import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const _url = 'https://elearningfrcpath.com/';
const _host = 'elearningfrcpath.com';

// capture:true fires BEFORE any page JS can call stopPropagation.
// Robust scrollTop works across all mobile browsers / WebView versions.
const _pullJs = r'''
(function() {
  if (window.__fptr) return;
  window.__fptr = true;
  var sy = 0, go = false;
  function top() {
    return window.scrollY || window.pageYOffset ||
      (document.documentElement ? document.documentElement.scrollTop : 0) || 0;
  }
  document.addEventListener('touchstart', function(e) {
    sy = e.touches[0].clientY; go = false;
  }, {capture: true, passive: true});
  document.addEventListener('touchmove', function(e) {
    if (top() < 5 && (e.touches[0].clientY - sy) > 60) go = true;
  }, {capture: true, passive: true});
  document.addEventListener('touchend', function() {
    if (go) { go = false; FlutterPTR.postMessage('r'); }
  }, {capture: true, passive: true});
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

    // Preload during splash for faster first paint
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Mimic Chrome mobile so the site serves correct CSS/layout
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; K) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(Uri.parse(_url));

    // Disable Android font boosting — prevents WebView from auto-scaling
    // text which breaks element sizing and shifts the search bar layout.
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setTextZoom(100);
    }

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

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasPageError = false;
  bool _isOnline = true;
  int _progress = 0;

  // Prevents loading overlay from showing when Android briefly reloads
  // the WebView after the app comes back from the background.
  bool _hasEverLoaded = false;
  bool _suppressNextPageStart = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupConnectivity();
    _setupController();
    _checkIfAlreadyLoaded();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasEverLoaded) {
      // Suppress the brief loading flash when Android resumes the WebView
      _suppressNextPageStart = true;
      // Safety reset: clear flag after 3s if no page events fire
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _suppressNextPageStart = false;
      });
    }
  }

  // ── Controller ───────────────────────────────────────────────────────────────

  void _setupController() {
    widget.controller.addJavaScriptChannel(
      'FlutterPTR',
      onMessageReceived: (_) => _triggerRefresh(),
    );

    widget.controller.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (_) {
        if (_suppressNextPageStart) {
          _suppressNextPageStart = false;
          return; // Don't show overlay for background-resume reloads
        }
        setState(() {
          _isLoading = true;
          _hasPageError = false;
          _progress = 0;
        });
      },
      onProgress: (p) => setState(() => _progress = p),
      onPageFinished: (_) {
        _hasEverLoaded = true;
        _suppressNextPageStart = false;
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        _inject();
      },
      onWebResourceError: (error) {
        // Only show error page for main frame failures
        if (error.isForMainFrame == true) {
          setState(() {
            _isLoading = false;
            _hasPageError = true;
          });
        }
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

  void _inject() => widget.controller.runJavaScript(_pullJs);

  Future<void> _triggerRefresh() async {
    if (_isRefreshing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isRefreshing = true);
    await widget.controller.loadRequest(Uri.parse(_url));
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
        _hasEverLoaded = true;
        setState(() => _isLoading = false);
        _inject();
      }
    } catch (_) {}
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _retryPage() async {
    setState(() {
      _hasPageError = false;
      _isLoading = true;
    });
    await widget.controller.loadRequest(Uri.parse(_url));
  }

  Future<void> _retryConnection() async {
    final r = await Connectivity().checkConnectivity();
    if (!mounted) return;
    final on = _online(r);
    setState(() => _isOnline = on);
    if (on) widget.controller.loadRequest(Uri.parse(_url));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
              : _NoInternetScreen(onRetry: _retryConnection),
        ),
      ),
    );
  }

  Widget _webViewStack() {
    return Stack(
      children: [
        // WebView — no scroll wrapper, handles native scrolling itself
        WebViewWidget(controller: widget.controller),

        // Page-load error screen
        if (_hasPageError && !_isLoading)
          _ErrorScreen(onRetry: _retryPage),

        // Pull-to-refresh progress bar (JS-triggered)
        if (_isRefreshing && !_isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: Color(0xFF1565C0),
              backgroundColor: Color(0xFFE3F2FD),
            ),
          ),

        // Initial / navigation loading overlay with real progress
        if (_isLoading)
          Container(
            color: Colors.white,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  color: const Color(0xFF1565C0),
                  backgroundColor: const Color(0xFFE3F2FD),
                ),
                Expanded(
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
            ),
          ),
      ],
    );
  }
}

// ─── Error screen ─────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Color(0xFFBDBDBD),
              ),
              const SizedBox(height: 16),
              const Text(
                'Page could not be loaded',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF424242),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Something went wrong.\nPlease try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9E9E9E),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
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
      ),
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
                label: const Text('Try Again',
                    style: TextStyle(fontSize: 16)),
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
