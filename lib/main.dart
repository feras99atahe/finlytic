import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/finance_service.dart';
import 'theme/app_theme.dart';

bool firebaseAvailable = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    firebaseAvailable = true;
  } catch (_) {
    // Firebase not configured for this platform — local-only mode.
  }
  runApp(const FinlyticApp());
}

class FinlyticApp extends StatelessWidget {
  const FinlyticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FinanceService()..load()),
      ],
      child: MaterialApp(
        title: 'Finlytic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
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
