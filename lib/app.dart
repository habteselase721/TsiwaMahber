import 'package:flutter/material.dart';
import 'package:tsiwa_mahber/core/constants/app_constants.dart';
import 'package:tsiwa_mahber/core/services/app_lock_service.dart';
import 'package:tsiwa_mahber/core/theme/app_theme.dart';
import 'package:tsiwa_mahber/features/auth/presentation/auth_gate.dart';
import 'package:tsiwa_mahber/features/onboarding/presentation/onboarding_screen.dart';
import 'package:tsiwa_mahber/features/settings/presentation/lock_screen.dart';

class TsiwaApp extends StatefulWidget {
  const TsiwaApp({super.key});

  @override
  State<TsiwaApp> createState() => _TsiwaAppState();
}

class _TsiwaAppState extends State<TsiwaApp> with WidgetsBindingObserver {
  final _themeProvider = ThemeProvider();
  final _localeProvider = LocaleProvider.instance;
  final _lockService = AppLockService.instance;
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeProvider.addListener(_rebuild);
    _localeProvider.addListener(_rebuild);
    _lockService.addListener(_rebuild);
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final show = await OnboardingScreen.shouldShow();
    if (mounted) setState(() => _showOnboarding = show);
  }

  void _rebuild() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lockService.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _lockService.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeProvider.removeListener(_rebuild);
    _localeProvider.removeListener(_rebuild);
    _lockService.removeListener(_rebuild);
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: _themeProvider.theme,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_showOnboarding == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding == true) {
      return OnboardingScreen(
        onComplete: () {
          setState(() => _showOnboarding = false);
        },
      );
    }

    // Show lock screen overlay when app is locked.
    if (_lockService.isLocked) {
      return const LockScreen();
    }

    return AuthGate(
      themeProvider: _themeProvider,
      localeProvider: _localeProvider,
    );
  }
}
