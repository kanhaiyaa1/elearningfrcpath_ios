import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'bookmarks_screen.dart';

const _host = 'elearningfrcpath.com';

const _tabs = [
  {'label': 'Home', 'url': 'https://elearningfrcpath.com/', 'icon': 'home'},
  {'label': 'FRCPath', 'url': 'https://www.elearningfrcpath.com/frcpath-part-1-histopathology-course', 'icon': 'book'},
  {'label': 'Contact', 'url': 'https://www.elearningfrcpath.com/contact', 'icon': 'contact'},
  {'label': 'Login', 'url': 'https://www.elearningfrcpath.com/login', 'icon': 'person'},
];

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const MyApp());
  _initFirebase();
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _setupFCM();
  } catch (e) {
    debugPrint('Firebase error: $e');
  }
}

Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;

  await Future.delayed(const Duration(seconds: 3));

  await messaging.requestPermission(alert: true, badge: true, sound: true);
  try {
    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');
  } catch (e) {
    debugPrint('FCM error: $e');
  }
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );
  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('Message: ${message.notification?.title}');
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
    Future.delayed(const Duration(seconds: 1), () {
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
          width: 250, height: 250,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.school, size: 100, color: Color(0xFF2E7D32)),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  int _progress = 0;
  bool _isOnline = true;
  bool _hasPageError = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _setupConnectivity();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _isLoading = true;
          _hasPageError = false;
          _progress = 0;
        }),
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: (_) => setState(() => _isLoading = false),
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
          final host = uri.host;
          if (host.contains('youtube.com') || host.contains('youtu.be')) {
            return NavigationDecision.prevent;
          }
          if (host.isEmpty ||
              host.contains(_host) ||
              host.contains('google.com') ||
              host.contains('gstatic.com') ||
              host.contains('recaptcha.net') ||
              host.contains('googleapis.com')) {
            return NavigationDecision.navigate;
          }
          launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(_tabs[0]['url']!));
    _triggerRateUs();
  }

  void _setupConnectivity() {
    Connectivity().checkConnectivity().then((r) {
      if (mounted) setState(() => _isOnline = _online(r));
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) {
      final on = _online(r);
      if (on && !_isOnline) {
        _controller.loadRequest(Uri.parse(_tabs[_currentIndex]['url']!));
      }
      if (mounted) setState(() => _isOnline = on);
    });
  }

  bool _online(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  Future<void> _triggerRateUs() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt('session_count') ?? 0) + 1;
    await prefs.setInt('session_count', count);
    if (count == 3) {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    }
  }

  Future<void> _shareCurrentPage() async {
    final url = await _controller.currentUrl() ?? _tabs[_currentIndex]['url']!;
    final title = await _controller.getTitle() ?? 'eLearningFRCPath';
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      '$title\n$url',
      subject: title,
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }

  Future<void> _bookmarkCurrentPage() async {
    final url = await _controller.currentUrl() ?? _tabs[_currentIndex]['url']!;
    final title = await _controller.getTitle() ?? 'eLearningFRCPath';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookmarks') ?? [];
    if (raw.any((e) => e.contains(url))) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already bookmarked!')),
      );
      return;
    }
    raw.add('$title|||$url');
    await prefs.setStringList('bookmarks', raw);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmarked!'), backgroundColor: Color(0xFF2E7D32)),
    );
  }

  void _openBookmarks() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookmarksScreen(
        onOpenUrl: (url) => _controller.loadRequest(Uri.parse(url)),
      ),
    ));
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2E7D32),
          elevation: 0,
          title: Image.asset('assets/appIcon.png', height: 36,
            errorBuilder: (_, __, ___) =>
                const Text('eLearningFRCPath', style: TextStyle(color: Colors.white))),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.bookmark_border, color: Colors.white),
                onPressed: _bookmarkCurrentPage),
            IconButton(icon: const Icon(Icons.bookmarks_outlined, color: Colors.white),
                onPressed: _openBookmarks),
            IconButton(icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _shareCurrentPage),
          ],
        ),
        body: SafeArea(
          child: !_isOnline
              ? _NoInternetScreen(onRetry: () async {
                  final r = await Connectivity().checkConnectivity();
                  setState(() => _isOnline = _online(r));
                  if (_isOnline) _controller.loadRequest(Uri.parse(_tabs[_currentIndex]['url']!));
                })
              : Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_hasPageError && !_isLoading)
                      _ErrorScreen(onRetry: () {
                        setState(() { _hasPageError = false; _isLoading = true; });
                        _controller.loadRequest(Uri.parse(_tabs[_currentIndex]['url']!));
                      }),
                    if (_isLoading)
                      Container(
                        color: Colors.white,
                        child: Column(children: [
                          LinearProgressIndicator(
                            value: _progress > 0 ? _progress / 100 : null,
                            color: const Color(0xFF2E7D32),
                            backgroundColor: const Color(0xFFE8F5E9),
                          ),
                          Expanded(child: Center(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/appIcon.png', width: 100, height: 100,
                                errorBuilder: (_, __, ___) => const Icon(Icons.school, size: 80)),
                              const SizedBox(height: 24),
                              const CircularProgressIndicator(color: Color(0xFF2E7D32), strokeWidth: 3),
                            ],
                          ))),
                        ]),
                      ),
                  ],
                ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() { _currentIndex = i; _isLoading = true; });
            _controller.loadRequest(Uri.parse(_tabs[i]['url']!));
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'FRCPath'),
            BottomNavigationBarItem(icon: Icon(Icons.contact_mail_outlined), activeIcon: Icon(Icons.contact_mail), label: 'Contact'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Login'),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorScreen({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 60, color: Color(0xFFBDBDBD)),
        const SizedBox(height: 16),
        const Text('Page could not be loaded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white)),
      ])),
    );
  }
}

class _NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoInternetScreen({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_rounded, size: 60, color: Color(0xFFBDBDBD)),
      const SizedBox(height: 16),
      const Text('No Internet Connection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white)),
    ]));
  }
}