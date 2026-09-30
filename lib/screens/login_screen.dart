import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final login = TextEditingController();
  final password = TextEditingController();

  bool busy = false;
  bool hidePassword = true;
  String mode = 'Driver ID';

  @override
  void dispose() {
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;

    FocusScope.of(context).unfocus();

    final loginValue = login.text.trim();
    final passwordValue = password.text;

    if (loginValue.isEmpty) {
      snack(
        context,
        'Enter your $mode.',
        error: true,
      );
      return;
    }

    if (passwordValue.isEmpty) {
      snack(
        context,
        'Enter your password.',
        error: true,
      );
      return;
    }

    if (mode == 'Email' && !_validEmail(loginValue)) {
      snack(
        context,
        'Enter a valid email address.',
        error: true,
      );
      return;
    }

    if (mode == 'Phone' && !_validPhone(loginValue)) {
      snack(
        context,
        'Enter a valid Sri Lankan phone number.',
        error: true,
      );
      return;
    }

    setState(() => busy = true);

    try {
      await ApiService.login(
        login: loginValue,
        password: passwordValue,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        ),
            (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      snack(
        context,
        cleanError(e),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  bool _validEmail(String value) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(value);
  }

  bool _validPhone(String value) {
    final phone = value.replaceAll(RegExp(r'[\s-]'), '');

    return RegExp(
      r'^(\+94|0)7\d{8}$',
    ).hasMatch(phone);
  }

  TextInputType get _keyboardType {
    if (mode == 'Phone') {
      return TextInputType.phone;
    }

    if (mode == 'Email') {
      return TextInputType.emailAddress;
    }

    return TextInputType.text;
  }

  String get _hintText {
    if (mode == 'Phone') {
      return '+94 77 123 4567';
    }

    if (mode == 'Email') {
      return 'driver@gmail.com';
    }

    return 'EBK-DRV-0000';
  }

  IconData get _loginIcon {
    if (mode == 'Phone') {
      return Icons.phone;
    }

    if (mode == 'Email') {
      return Icons.email;
    }

    return Icons.badge;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: AutofillGroup(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/eastbus_logo.png',
                      width: 280,
                      height: 180,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 32),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Welcome Driver / Conductor',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sign in using credentials created by your Bus Operator.',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Driver ID',
                            icon: Icon(Icons.badge_outlined),
                            label: Text('ID'),
                          ),
                          ButtonSegment(
                            value: 'Phone',
                            icon: Icon(Icons.phone_outlined),
                            label: Text('Phone'),
                          ),
                          ButtonSegment(
                            value: 'Email',
                            icon: Icon(Icons.email_outlined),
                            label: Text('Email'),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: busy
                            ? null
                            : (selection) {
                          setState(() {
                            mode = selection.first;
                            login.clear();
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: login,
                      enabled: !busy,
                      keyboardType: _keyboardType,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: mode == 'Email'
                          ? const [AutofillHints.email]
                          : mode == 'Phone'
                          ? const [AutofillHints.telephoneNumber]
                          : const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: mode,
                        hintText: _hintText,
                        prefixIcon: Icon(_loginIcon),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: password,
                      enabled: !busy,
                      obscureText: hidePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) {
                        if (!busy) {
                          submit();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          onPressed: busy
                              ? null
                              : () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: busy ? null : submit,
                        child: busy
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text('Login'),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Don't have an account? Contact your Bus Operator.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}