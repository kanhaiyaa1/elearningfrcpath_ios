import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import 'bookmarks_screen.dart';
import 'notification_service.dart';
import 'reminder_screen.dart';
import 'reading_list_screen.dart';
import 'study_timer_screen.dart';
import 'dashboard_screen.dart';
import 'calendar_screen.dart';
import 'biometric_service.dart';
import 'lock_screen.dart';
import 'biometric_settings_screen.dart';
import 'delete_account_screen.dart';
import 'onboarding_screen.dart';
import 'quiz_screen.dart';

const _host = 'elearningfrcpath.com';

const _tabs = [
  {'label': 'Home', 'url': 'https://elearningfrcpath.com/', 'icon': 'home'},
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
  await NotificationService.initialize();
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
    alert: true,
    badge: true,
    sound: true,
  );

  // iOS handles badge count automatically via FCM when badge: true is set
  await FirebaseMessaging.instance.setAutoInitEnabled(true);

  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('Message: ${message.notification?.title}');
  });

  // Clear badge count when app is opened from notification
  FirebaseMessaging.onMessageOpenedApp.listen((_) {
    FirebaseMessaging.instance.setAutoInitEnabled(true);
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
      onUnknownRoute: (_) => MaterialPageRoute(builder: (_) => const SplashScreen()),
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
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      final biometricEnabled = await BiometricService.isBiometricEnabled();
      if (!mounted) return;
      if (biometricEnabled) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LockScreen(nextScreen: MainScreen()),
          ),
        );
      } else {
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
          errorBuilder: (_, _, _) =>
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
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; K) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Mobile Safari/537.36 ELC_APP/1.0',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          setState(() {
            _isLoading = true;
            _hasPageError = false;
            _progress = 0;
          });
          _controller.runJavaScript('''
            var style = document.createElement('style');
            style.textContent = `
              a[href*="cart/create"],
              a[href*="checkout"],
              a[href*="cart"] { display: none !important; }
            `;
            document.head.appendChild(style);
          ''');
        },
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: (url) async {
          setState(() => _isLoading = false);
          // Track pages visited
          final prefs = await SharedPreferences.getInstance();
          final pages = (prefs.getInt('pages_visited') ?? 0) + 1;
          await prefs.setInt('pages_visited', pages);
          // Try to get user_id from window variable
          try {
            final userId = await _controller.runJavaScriptReturningResult(
              'window.currentUserId ? String(window.currentUserId) : ""'
            );
            debugPrint('Raw userId captured: $userId');
            final idStr = userId.toString().replaceAll('"', '').trim();
            final id = int.tryParse(idStr);
            if (id != null && id > 0) {
              await prefs.setInt('user_id', id);
              debugPrint('Saved user_id: $id');
            }
          } catch (e) {
            debugPrint('userId capture error: $e');
          }
          // Hide all commercial/purchase/registration elements, pricing, and social login buttons
          _controller.runJavaScript('''
            (function() {
              function cleanCommercialContent() {
                document.querySelectorAll('a, button').forEach(function(el) {
                  var text = el.innerText.trim().toLowerCase();
                  var href = (el.getAttribute('href') || '').toLowerCase();
                  if (text.includes('view study material') ||
                      text.includes('view course') ||
                      text.includes('buy now') ||
                      text.includes('add to cart') ||
                      text.includes('register') ||
                      text.includes('continue with google') ||
                      text.includes('sign in with apple') ||
                      text.includes('continue with apple') ||
                      href.includes('/register') ||
                      href.includes('/course/') ||
                      href.includes('cart')) {
                    el.style.display = 'none';
                  }
                });

                var priceRegex = /(INR|₹)\\s*[\\d,]+/i;
                document.querySelectorAll('body *').forEach(function(el) {
                  if (el.children.length === 0 && el.innerText && priceRegex.test(el.innerText)) {
                    el.style.display = 'none';
                  }
                });
              }

              cleanCommercialContent();
              var observer = new MutationObserver(cleanCommercialContent);
              observer.observe(document.body, { childList: true, subtree: true });
            })();
          ''');
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
          final host = uri.host;

          // Block YouTube
          if (host.contains('youtube.com') || host.contains('youtu.be')) {
            return NavigationDecision.prevent;
          }

          // Block course catalog and registration pages (Apple IAP compliance)
          if (req.url.contains('/course/') || req.url.contains('/register')) {
            return NavigationDecision.prevent;
          }

          // Social login buttons hidden from UI and native handlers disabled
          // (kept for reference but not active)
          // if (Platform.isIOS && (
          //     req.url.contains('appleid.apple.com') ||
          //     req.url.contains('/auth/apple') ||
          //     (req.url.contains('apple') && req.url.contains('authorize')))) {
          //   _handleAppleSignIn();
          //   return NavigationDecision.prevent;
          // }

          // if (req.url.contains('/login/google') &&
          //     !req.url.contains('callback') &&
          //     !req.url.contains('success')) {
          //   _handleGoogleSignIn();
          //   return NavigationDecision.prevent;
          // }

          // Allow login providers inside WebView
          if (host.contains('accounts.google.com') ||
              host.contains('appleid.apple.com') ||
              host.contains('apple.com')) {
            return NavigationDecision.navigate;
          }

          // Allow internal + auth domains
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
      ..addJavaScriptChannel('FlutterOpenUrl',
          onMessageReceived: (msg) {
            launchUrl(Uri.parse(msg.message), mode: LaunchMode.externalApplication);
          })
      ..addJavaScriptChannel('DeleteResult',
          onMessageReceived: (msg) => deleteResultCallback?.call(msg.message))
      ..addJavaScriptChannel('DebugSession',
          onMessageReceived: (msg) => debugPrint('Session debug: ${msg.message}'))
      ..loadRequest(Uri.parse(_tabs[0]['url']!));
    _triggerRateUs();
    _handleDeepLinks();
    _showOnboarding();
  }

  Future<void> _showOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('onboarding_shown') ?? false;
    if (!shown) {
      await prefs.setBool('onboarding_shown', true);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        ));
      }
    }
  }

  void _handleDeepLinks() async {
    final appLinks = AppLinks();

    // Handle cold start (app opened via deep link)
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _processDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Initial deep link error: $e');
    }

    // Handle warm start (app already open)
    appLinks.uriLinkStream.listen((uri) {
      _processDeepLink(uri);
    });
  }

  void _processDeepLink(Uri uri) {
    if (uri.scheme == 'elearningfrcpath' && uri.host == 'login-success') {
      final token = uri.queryParameters['token'];
      debugPrint('Deep link token: $token');
      if (token != null) {
        _controller.loadRequest(
          Uri.parse('https://www.elearningfrcpath.com/login/google/success/$token'),
        );
      } else {
        _controller.loadRequest(Uri.parse('https://www.elearningfrcpath.com'));
      }
    }
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
    HapticFeedback.lightImpact();
    final url = await _controller.currentUrl() ?? _tabs[_currentIndex]['url']!;
    final title = await _controller.getTitle() ?? 'eLearningFRCPath';
    if (!mounted) return;
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
    HapticFeedback.lightImpact();
    final url = await _controller.currentUrl() ?? _tabs[_currentIndex]['url']!;
    final title = await _controller.getTitle() ?? 'eLearningFRCPath';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookmarks') ?? [];
    if (raw.any((e) => e.contains(url))) {
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
        const SnackBar(content: Text('Bookmarked!'), backgroundColor: Color(0xFF2E7D32)),
      );
    }
  }

  Future<void> _saveToReadingList() async {
    HapticFeedback.lightImpact();
    final url = await _controller.currentUrl() ?? _tabs[_currentIndex]['url']!;
    final title = await _controller.getTitle() ?? 'eLearningFRCPath';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('reading_list') ?? [];

    final exists = raw.any((e) {
      final item = jsonDecode(e);
      return item['url'] == url;
    });

    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already in reading list!')),
        );
      }
      return;
    }

    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final item = ReadingListItem(
      title: title,
      url: url,
      savedAt: 'Saved ${now.day}/${now.month}/${now.year} at $hour:$minute',
    );

    raw.add(jsonEncode(item.toJson()));
    await prefs.setStringList('reading_list', raw);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to Reading List ✅'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
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
            errorBuilder: (_, _, _) =>
                const Text('eLearningFRCPath', style: TextStyle(color: Colors.white))),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.quiz_outlined, color: Colors.white, size: 22),
              onPressed: () { HapticFeedback.lightImpact(); Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const QuizScreen())); },
              tooltip: 'FRCPath MCQ Quiz',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_border, color: Colors.white, size: 22),
              onPressed: _bookmarkCurrentPage,
              tooltip: 'Bookmark',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white, size: 22),
              onPressed: _shareCurrentPage,
              tooltip: 'Share',
              visualDensity: VisualDensity.compact,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                HapticFeedback.lightImpact();
                switch (value) {
                  case 'bookmarks':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BookmarksScreen(
                        onOpenUrl: (url) => _controller.loadRequest(Uri.parse(url)),
                      ),
                    ));
                  case 'reading_list_save':
                    _saveToReadingList();
                  case 'reading_list_view':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ReadingListScreen(
                        onOpenUrl: (url) => _controller.loadRequest(Uri.parse(url)),
                      ),
                    ));
                  case 'dashboard':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DashboardScreen(
                        onOpenUrl: (url) => _controller.loadRequest(Uri.parse(url)),
                      ),
                    ));
                  case 'calendar':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const CalendarScreen(),
                    ));
                  case 'reminder':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ReminderScreen(),
                    ));
                  case 'timer':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const StudyTimerScreen(),
                    ));
                  case 'security':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BiometricSettingsScreen(controller: _controller),
                    ));
                }
              },
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'bookmarks', child: Text('My Bookmarks')),
                const PopupMenuItem(value: 'reading_list_save', child: Text('Save to Reading List')),
                const PopupMenuItem(value: 'reading_list_view', child: Text('Reading List')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'dashboard', child: Text('Dashboard')),
                const PopupMenuItem(value: 'calendar', child: Text('Study Calendar')),
                const PopupMenuItem(value: 'reminder', child: Text('Study Reminder')),
                const PopupMenuItem(value: 'timer', child: Text('Study Timer')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'security', child: Text('Security')),
              ],
            ),
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
                                errorBuilder: (_, _, _) => const Icon(Icons.school, size: 80)),
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
            HapticFeedback.lightImpact();
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