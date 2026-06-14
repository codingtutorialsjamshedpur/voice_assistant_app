import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

enum AppThemeMode { system, light, dark }

class ThemeService extends GetxService with WidgetsBindingObserver {
  static ThemeService get to => Get.find<ThemeService>();

  final _box = GetStorage();
  final _key = 'app_theme_mode';

  final Rx<AppThemeMode> appThemeMode = AppThemeMode.system.obs;

  Future<ThemeService> init() async {
    final String? savedMode = _box.read(_key);
    if (savedMode != null) {
      appThemeMode.value = _parseThemeMode(savedMode);
    } else {
      appThemeMode.value = AppThemeMode.system;
    }
    WidgetsBinding.instance.addObserver(this);
    _applyTheme();
    return this;
  }

  AppThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }

  String _themeModeToString(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
    }
  }

  ThemeMode get themeMode {
    switch (appThemeMode.value) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Brightness get resolvedBrightness {
    if (appThemeMode.value == AppThemeMode.dark) return Brightness.dark;
    if (appThemeMode.value == AppThemeMode.light) return Brightness.light;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  void cycleMode() {
    final currentIndex = appThemeMode.value.index;
    final nextIndex = (currentIndex + 1) % AppThemeMode.values.length;
    appThemeMode.value = AppThemeMode.values[nextIndex];
    _box.write(_key, _themeModeToString(appThemeMode.value));
    _applyTheme();
  }

  void setMode(AppThemeMode mode) {
    if (appThemeMode.value != mode) {
      appThemeMode.value = mode;
      _box.write(_key, _themeModeToString(mode));
      _applyTheme();
    }
  }

  void _applyTheme() {
    Get.changeThemeMode(themeMode);

    final brightness = resolvedBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        appThemeMode.value == AppThemeMode.system) {
      _applyTheme();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}