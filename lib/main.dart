import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;

  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('EastBus Firebase initialization failed: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('staff_token')?.trim() ?? '';
  final hasToken = token.isNotEmpty;

  runApp(
    EastBusApp(
      hasToken: hasToken,
      firebaseReady: firebaseReady,
    ),
  );
}

class EastBusApp extends StatelessWidget {
  final bool hasToken;
  final bool firebaseReady;

  const EastBusApp({
    super.key,
    required this.hasToken,
    required this.firebaseReady,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF064BD8);
    const darkBlue = Color(0xFF0A1E52);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EastBus Trip Management',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        scaffoldBackgroundColor: const Color(0xFFF7F9FD),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: darkBlue,
          elevation: 0,
          centerTitle: false,
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFD8DFEA),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: blue,
              width: 1.5,
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: SplashGate(
        firebaseReady: firebaseReady,
        next: hasToken
            ? const DashboardScreen()
            : const LoginScreen(),
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  final Widget next;
  final bool firebaseReady;

  const SplashGate({
    super.key,
    required this.next,
    required this.firebaseReady,
  });

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _openNextScreen();
  }

  Future<void> _openNextScreen() async {
    await Future.delayed(
      const Duration(milliseconds: 1600),
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => widget.next,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/eastbus_logo.png',
                  width: 180,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return const Icon(
                      Icons.directions_bus_rounded,
                      size: 100,
                      color: Color(0xFF064BD8),
                    );
                  },
                ),

                const SizedBox(height: 12),

                const Text(
                  'EastBus.lk',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0A1E52),
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'TRIP MANAGEMENT',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.3,
                    color: Color(0xFF064BD8),
                  ),
                ),

                const SizedBox(height: 36),

                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF064BD8),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Drive Safe, Serve Better',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),

                if (!widget.firebaseReady) ...[
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 16,
                        color: Colors.red,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Firebase connection unavailable',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}