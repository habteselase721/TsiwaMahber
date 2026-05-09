import 'package:flutter/material.dart';
import 'package:tsiwa_mahber/core/l10n/app_strings.dart';
import 'package:tsiwa_mahber/core/services/app_lock_service.dart';
import 'package:tsiwa_mahber/core/theme/app_theme.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() =>
      _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final _lockService = AppLockService.instance;
  bool _canUseBio = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _lockService.addListener(_onChanged);
  }

  @override
  void dispose() {
    _lockService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkBiometrics() async {
    final can = await _lockService.canUseBiometrics;
    if (mounted) {
      setState(() {
        _canUseBio = can;
        _loading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Verify biometric before enabling.
      final success = await _lockService.authenticate(
        reason: S.verifyToEnable,
      );
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.authFailed)),
          );
        }
        return;
      }
    }
    await _lockService.setBiometricEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(S.appLockSettings)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(S.appLockSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Biometric toggle
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint,
                  color: AppTheme.primary),
              title: Text(S.biometricAuth),
              subtitle: Text(
                _canUseBio
                    ? S.biometricAuthDesc
                    : S.biometricNotAvailable,
              ),
              value: _lockService.biometricEnabled,
              activeTrackColor: AppTheme.primary,
              onChanged: _canUseBio ? _toggleBiometric : null,
            ),
          ),
          const SizedBox(height: 16),

          // Lock timeout chooser
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        S.lockTimeout,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    S.lockTimeoutDesc,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildTimeoutRadios(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lock now button
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock, color: AppTheme.primary),
              title: Text(S.lockNow),
              subtitle: Text(S.lockNowDesc),
              trailing: const Icon(Icons.chevron_right),
              enabled: _lockService.biometricEnabled,
              onTap: _lockService.biometricEnabled
                  ? () {
                      _lockService.lockNow();
                      Navigator.of(context).popUntil(
                          (route) => route.isFirst);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutRadios() {
    final enabled = _lockService.biometricEnabled;
    if (enabled) {
      void onChanged(LockTimeout? val) {
        if (val != null) _lockService.setLockTimeout(val);
      }
      return RadioGroup<LockTimeout>(
        groupValue: _lockService.lockTimeout,
        onChanged: onChanged,
        child: Column(
          children: LockTimeout.values.map((t) {
            return RadioListTile<LockTimeout>(
              value: t,
              title: Text(_timeoutLabel(t)),
              activeColor: AppTheme.primary,
            );
          }).toList(),
        ),
      );
    }
    // When disabled, render without RadioGroup so radios appear disabled.
    return Column(
      children: LockTimeout.values.map((t) {
        return RadioListTile<LockTimeout>(
          value: t,
          // ignore: deprecated_member_use
          groupValue: _lockService.lockTimeout,
          // ignore: deprecated_member_use
          onChanged: null,
          title: Text(
            _timeoutLabel(t),
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          activeColor: AppTheme.primary,
        );
      }).toList(),
    );
  }

  String _timeoutLabel(LockTimeout t) {
    switch (t) {
      case LockTimeout.immediately:
        return S.timeoutImmediately;
      case LockTimeout.oneMinute:
        return S.timeoutOneMin;
      case LockTimeout.fiveMinutes:
        return S.timeoutFiveMin;
      case LockTimeout.thirtyMinutes:
        return S.timeoutThirtyMin;
      case LockTimeout.oneHour:
        return S.timeoutOneHour;
      case LockTimeout.never:
        return S.timeoutNever;
    }
  }
}
