import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthService>();
    final err = _isLogin
        ? await auth.login(_emailCtrl.text, _passCtrl.text)
        : await auth.register(_emailCtrl.text, _passCtrl.text);

    if (mounted) {
      setState(() { _loading = false; _error = err; });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    final auth = context.read<AuthService>();
    final err = await auth.resetPassword(email);
    if (mounted) {
      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset link sent to $email',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            backgroundColor: AppTheme.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _error = err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.light,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.orange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_graph_rounded,
                      color: AppTheme.light, size: 30),
                ),
                const SizedBox(height: 32),

                // Headline
                Text(
                  _isLogin ? 'Welcome\nback.' : 'Create your\naccount.',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dark,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Sign in to access your wallet.'
                      : 'Start tracking your finances.',
                  style: GoogleFonts.lora(
                    fontSize: 15,
                    color: AppTheme.midGray,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email.';
                    if (!v.contains('@')) return 'Enter a valid email.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password.';
                    if (!_isLogin && v.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                ),

                // Forgot password
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  )
                else
                  const SizedBox(height: 16),

                // Error message
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.orange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.orange,
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.light,
                            ))
                        : Text(_isLogin ? 'Sign In' : 'Create Account'),
                  ),
                ),
                const SizedBox(height: 24),

                // Toggle login / register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin
                          ? "Don't have an account?"
                          : 'Already have an account?',
                      style: GoogleFonts.lora(
                          fontSize: 13, color: AppTheme.midGray),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _isLogin = !_isLogin;
                        _error = null;
                      }),
                      child: Text(_isLogin ? 'Register' : 'Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
