import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'bookmarks_screen.dart';
const _host = 'elearningfrcpath.com';

const _tabs = [
  {'label': 'Home', 'url': 'https://elearningfrcpath.com/'},
  {'label': 'FRCPath', 'url': 'https://www.elearningfrcpath.com/frcpath-part-1-histopathology-course'},
  {'label': 'Contact', 'url': 'https://www.elearningfrcpath.com/contact'},
  {'label': 'Login', 'url': 'https://www.elearningfrcpath.com/login'},
];

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

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp();
  await _setupFCM();
  runApp(const MyApp());
}

Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;
  
  // Request permission (iOS requires this)
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get FCM token (for testing)
  final token = await messaging.getToken();
  debugPrint('FCM Token: $token');

  // Handle foreground notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eLearningFRCPath',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2E7D32),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
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
  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
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

// ─── Main Screen with Bottom Nav ──────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<WebViewController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _tabs.map((tab) {
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; K) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/124.0.0.0 Mobile Safari/537.36',
        )
        ..loadRequest(Uri.parse(tab['url']!));

      if (c.platform is AndroidWebViewController) {
        (c.platform as AndroidWebViewController).setTextZoom(100);
      }
      return c;
    }).toList();
    _triggerRateUs();
  }

  Future<void> _triggerRateUs() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionCount = (prefs.getInt('session_count') ?? 0) + 1;
    await prefs.setInt('session_count', sessionCount);

    if (sessionCount == 3) {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    }
  }

  Future<void> _shareCurrentPage() async {
    final controller = _controllers[_currentIndex];
    final url = await controller.currentUrl() ?? _tabs[_currentIndex]['url']!;
    final title = await controller.getTitle() ?? 'eLearningFRCPath';
    Share.share('$title\n$url', subject: title);
  }

  Future<void> _bookmarkCurrentPage() async {
    final controller = _controllers[_currentIndex];
    final url = await controller.currentUrl() ?? _tabs[_currentIndex]['url']!;
    final title = await controller.getTitle() ?? 'eLearningFRCPath';

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookmarks') ?? [];

    final exists = raw.any((e) => e.contains(url));
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already bookmarked!')),
        );
      }
      return;
    }

    raw.add('$title|||$url');
    await prefs.setStringList('bookmarks', raw);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bookmark saved!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  void _openBookmarks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(
          onOpenUrl: (url) {
            _controllers[_currentIndex].loadRequest(Uri.parse(url));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controllers[_currentIndex].canGoBack()) {
          _controllers[_currentIndex].goBack();
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          elevation: 0,
          title: Image.asset('assets/appIcon.png', height: 36),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_border, color: Colors.white),
              onPressed: _bookmarkCurrentPage,
              tooltip: 'Bookmark',
            ),
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined, color: Colors.white),
              onPressed: _openBookmarks,
              tooltip: 'View Bookmarks',
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareCurrentPage,
              tooltip: 'Share',
            ),
          ],
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: List.generate(
              _tabs.length,
              (i) => WebViewTab(
                controller: _controllers[i],
                url: _tabs[i]['url']!,
              ),
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'FRCPath',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.contact_mail_outlined),
              activeIcon: Icon(Icons.contact_mail),
              label: 'Contact',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Login',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WebView Tab ──────────────────────────────────────────────────────────────

class WebViewTab extends StatefulWidget {
  final WebViewController controller;
  final String url;
  const WebViewTab({super.key, required this.controller, required this.url});
  @override
  State<WebViewTab> createState() => _WebViewTabState();
}

class _WebViewTabState extends State<WebViewTab> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasPageError = false;
  bool _isOnline = true;
  int _progress = 0;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasEverLoaded) {
      _suppressNextPageStart = true;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _suppressNextPageStart = false;
      });
    }
  }

  void _setupController() {
    widget.controller.addJavaScriptChannel(
      'FlutterPTR',
      onMessageReceived: (_) => _triggerRefresh(),
    );

    widget.controller.setNavigationDelegate(NavigationDelegate(
      onPageStarted: (_) {
        if (_suppressNextPageStart) {
          _suppressNextPageStart = false;
          return;
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
    await widget.controller.loadRequest(Uri.parse(widget.url));
  }

  void _setupConnectivity() {
    Connectivity().checkConnectivity().then((r) {
      if (mounted) setState(() => _isOnline = _online(r));
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) {
      final on = _online(r);
      if (on && !_isOnline) {
        widget.controller.loadRequest(Uri.parse(widget.url));
      }
      if (mounted) setState(() => _isOnline = on);
    });
  }

  bool _online(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

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

  Future<void> _retryPage() async {
    setState(() {
      _hasPageError = false;
      _isLoading = true;
    });
    await widget.controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _retryConnection() async {
    final r = await Connectivity().checkConnectivity();
    if (!mounted) return;
    final on = _online(r);
    setState(() => _isOnline = on);
    if (on) widget.controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOnline) {
      return _NoInternetScreen(onRetry: _retryConnection);
    }

    return Stack(
      children: [
        WebViewWidget(controller: widget.controller),
        if (_isLoading && _hasEverLoaded)
          Positioned(
            top: 0, left: 0, right: 0,
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress / 100 : null,
              color: const Color(0xFF2E7D32),
              backgroundColor: const Color(0xFFE8F5E9),
              minHeight: 3,
            ),
          ),
        if (_hasPageError && !_isLoading)
          _ErrorScreen(onRetry: _retryPage),
        if (_isRefreshing && !_isLoading)
          const Positioned(
            top: 0, left: 0, right: 0,
            child: LinearProgressIndicator(
              color: Color(0xFF2E7D32),
              backgroundColor: Color(0xFFE8F5E9),
            ),
          ),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  color: const Color(0xFF2E7D32),
                  backgroundColor: const Color(0xFFE8F5E9),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/appIcon.png',
                            width: 100, height: 100,
                            filterQuality: FilterQuality.high),
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 32, height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF2E7D32),
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
              const Icon(Icons.error_outline_rounded,
                  size: 60, color: Color(0xFFBDBDBD)),
              const SizedBox(height: 16),
              const Text('Page could not be loaded',
                  style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w700, color: Color(0xFF424242))),
              const SizedBox(height: 8),
              const Text('Something went wrong.\nPlease try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14,
                      color: Color(0xFF9E9E9E), height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
              child: Image.asset('assets/appIcon.png',
                  width: 80, height: 80,
                  filterQuality: FilterQuality.high),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.wifi_off_rounded,
                size: 60, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 16),
            const Text('No Internet Connection',
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w700, color: Color(0xFF424242))),
            const SizedBox(height: 8),
            const Text('Please check your connection\nand try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: Color(0xFF9E9E9E), height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}