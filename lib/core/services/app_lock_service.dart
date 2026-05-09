import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long after the app goes to background before re-auth is required.
enum LockTimeout {
  immediately(0, 'immediately'),
  oneMinute(60, '1min'),
  fiveMinutes(300, '5min'),
  thirtyMinutes(1800, '30min'),
  oneHour(3600, '1h'),
  never(-1, 'never');

  final int seconds;
  final String key;
  const LockTimeout(this.seconds, this.key);

  static LockTimeout fromKey(String? key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return immediately;
  }
}

/// Manages app-lock settings and state using SharedPreferences + local_auth.
class AppLockService extends ChangeNotifier {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const _keyBiometricEnabled = 'applock_biometric_enabled';
  static const _keyLockTimeout = 'applock_timeout';
  static const _keyBackgroundedAt = 'applock_backgrounded_at';

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _biometricEnabled = false;
  LockTimeout _lockTimeout = LockTimeout.immediately;
  bool _isLocked = false;
  bool _initialized = false;

  bool get biometricEnabled => _biometricEnabled;
  LockTimeout get lockTimeout => _lockTimeout;
  bool get isLocked => _isLocked;
  bool get isEnabled => _biometricEnabled;

  /// Whether the device supports any biometrics.
  Future<bool> get canUseBiometrics async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Available biometric types on the device.
  Future<List<BiometricType>> get availableBiometrics async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _biometricEnabled = prefs.getBool(_keyBiometricEnabled) ?? false;
    _lockTimeout =
        LockTimeout.fromKey(prefs.getString(_keyLockTimeout));
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, value);
    if (!value) {
      _isLocked = false;
    }
    notifyListeners();
  }

  Future<void> setLockTimeout(LockTimeout timeout) async {
    _lockTimeout = timeout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLockTimeout, timeout.key);
    notifyListeners();
  }

  /// Call when the app goes to background.
  Future<void> onAppPaused() async {
    if (!_biometricEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _keyBackgroundedAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Call when the app returns to foreground. Returns true if lock is needed.
  Future<bool> onAppResumed() async {
    if (!_biometricEnabled) return false;
    if (_lockTimeout == LockTimeout.never) return false;

    final prefs = await SharedPreferences.getInstance();
    final bgAt = prefs.getInt(_keyBackgroundedAt);
    if (bgAt == null) return false;

    if (_lockTimeout == LockTimeout.immediately) {
      _isLocked = true;
      notifyListeners();
      return true;
    }

    final elapsed =
        DateTime.now().millisecondsSinceEpoch - bgAt;
    if (elapsed >= _lockTimeout.seconds * 1000) {
      _isLocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Instantly lock the app (one-click lock button).
  void lockNow() {
    if (!_biometricEnabled) return;
    _isLocked = true;
    notifyListeners();
  }

  /// Attempt biometric authentication to unlock.
  Future<bool> authenticate({String reason = 'Authenticate to unlock'}) async {
    try {
      final success = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (success) {
        _isLocked = false;
        notifyListeners();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Unlock without biometric (e.g. after code entry).
  void unlock() {
    _isLocked = false;
    notifyListeners();
  }
}
