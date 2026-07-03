import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the app behind a PIN (and optional biometrics). The PIN is stored in
/// the platform keystore/keychain via [FlutterSecureStorage] — never in plain
/// shared-prefs. Only the *enabled* flag lives in shared-prefs.
///
/// Default state is disabled, so existing users are unaffected until they opt
/// in from Profile → Preferences.
class AppLockService extends ChangeNotifier {
  static const _kEnabledKey = 'app_lock_enabled';
  static const _kPinKey = 'app_lock_pin';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _enabled = false;
  bool _locked = false;

  /// Whether the user has turned app lock on.
  bool get enabled => _enabled;

  /// Whether the app is currently locked and should show the lock screen.
  bool get locked => _locked;

  /// Loads the persisted state. When lock is on, the app starts locked.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabledKey) ?? false;
    _locked = _enabled;
    notifyListeners();
  }

  /// True if the device has biometrics (or device credential) available.
  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Turns app lock on and stores the [pin] securely.
  Future<void> enable(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await _secure.write(key: _kPinKey, value: pin);
    await prefs.setBool(_kEnabledKey, true);
    _enabled = true;
    _locked = false;
    notifyListeners();
  }

  /// Turns app lock off and clears the stored PIN.
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await _secure.delete(key: _kPinKey);
    await prefs.setBool(_kEnabledKey, false);
    _enabled = false;
    _locked = false;
    notifyListeners();
  }

  /// Called when the app goes to the background — re-locks if enabled.
  void lockIfEnabled() {
    if (_enabled && !_locked) {
      _locked = true;
      notifyListeners();
    }
  }

  /// Verifies a typed PIN. Unlocks on match.
  Future<bool> unlockWithPin(String pin) async {
    final stored = await _secure.read(key: _kPinKey);
    final ok = stored != null && stored == pin;
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// Prompts the OS biometric/credential sheet. Unlocks on success.
  Future<bool> unlockWithBiometrics() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock Finlytic',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (ok) {
        _locked = false;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }
}
