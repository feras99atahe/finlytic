import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/app_lock_service.dart';
import '../theme/app_theme.dart';

/// Full-screen gate shown over the whole app while [AppLockService] is locked.
/// Offers PIN entry and, when available, a biometric prompt.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinCtrl = TextEditingController();
  bool _canBiometric = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lock = context.read<AppLockService>();
      final can = await lock.canUseBiometrics();
      if (mounted) setState(() => _canBiometric = can);
      if (can) lock.unlockWithBiometrics();
    });
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    final ok = await context.read<AppLockService>().unlockWithPin(_pinCtrl.text);
    if (!ok && mounted) {
      setState(() => _error = true);
      _pinCtrl.clear();
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.read<AppLockService>();
    return Scaffold(
      backgroundColor: AppTheme.light,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.orange,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: AppTheme.light, size: 34),
                ),
                const SizedBox(height: 24),
                Text(
                  'Finlytic is locked',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your PIN to continue.',
                  style: GoogleFonts.lora(
                      fontSize: 14, color: AppTheme.midGray),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _pinCtrl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 12,
                  onChanged: (_) {
                    if (_error) setState(() => _error = false);
                  },
                  onSubmitted: (_) => _submitPin(),
                  style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    errorText: _error ? 'Incorrect PIN' : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitPin,
                    child: const Text('Unlock'),
                  ),
                ),
                if (_canBiometric) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => lock.unlockWithBiometrics(),
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Use biometrics'),
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
