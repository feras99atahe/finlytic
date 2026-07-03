import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'quick_add_popup.dart';
import 'screens/lock_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/app_lock_service.dart';
import 'services/auth_service.dart';
import 'services/finance_service.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';

bool firebaseAvailable = false;

/// Entrypoint for the home-screen widget quick-add popup (translucent
/// `QuickAddActivity`). Must live in the root library so the Flutter engine can
/// resolve it by name; delegates to the popup UI in quick_add_popup.dart.
@pragma('vm:entry-point')
void quickAddMain(List<String> args) => runQuickAddPopup(args);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    firebaseAvailable = true;
  } catch (_) {
    // Firebase not configured for this platform — local-only mode.
  }

  // Set up reminders (re-arms the schedule after a reboot) and the widget
  // bridge. These are non-critical: a failure here must NEVER prevent the app
  // UI from launching, otherwise the user is stuck on a black screen.
  try {
    await NotificationService.instance.init();
    await NotificationService.instance.applySchedule();
  } catch (e, st) {
    debugPrint('Notification setup failed (ignored): $e\n$st');
  }
  try {
    await WidgetService.init();
  } catch (e, st) {
    debugPrint('Widget setup failed (ignored): $e\n$st');
  }

  runApp(const FinlyticApp());
}

class FinlyticApp extends StatefulWidget {
  const FinlyticApp({super.key});

  @override
  State<FinlyticApp> createState() => _FinlyticAppState();
}

class _FinlyticAppState extends State<FinlyticApp>
    with WidgetsBindingObserver {
  // Held so we can reload after the quick-add widget popup writes new data.
  final FinanceService _finance = FinanceService()..load();
  final AppLockService _appLock = AppLockService()..init();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The home-screen quick-add popup runs in a separate engine and writes
    // straight to the database; reload so its entries show when we resume.
    if (state == AppLifecycleState.resumed) {
      _finance.load();
      WidgetService.updateBalance(_finance.totalBalance);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Re-lock as soon as the app leaves the foreground.
      _appLock.lockIfEnabled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider.value(value: _finance),
        ChangeNotifierProvider.value(value: _appLock),
      ],
      child: MaterialApp(
        title: 'Finlytic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          // Overlay the lock screen above every route when locked. We listen to
          // the service via AnimatedBuilder (not context.watch) because
          // depending on an InheritedWidget inside MaterialApp.builder throws a
          // framework assertion when a route is torn down during a notify.
          return AnimatedBuilder(
            animation: _appLock,
            builder: (context, _) => Stack(
              children: [
                if (child != null) child,
                if (_appLock.locked) const LockScreen(),
              ],
            ),
          );
        },
        home: firebaseAvailable ? const _AuthGate() : const MainShell(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _timedOut = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // If auth state hasn't resolved in 5 s, fall through to login screen.
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_timedOut) {
          return const Scaffold(
            backgroundColor: AppTheme.light,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.orange),
            ),
          );
        }
        if (snapshot.data == null) return const LoginScreen();
        return const MainShell();
      },
    );
  }
}
