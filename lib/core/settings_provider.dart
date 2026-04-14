import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // الوضع الافتراضي: مظلم
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('ar');
  bool _notificationsEnabled = true;
  String _reminderTiming = '12 ساعة قبل'; // خيارات: 'ساعة قبل', '12 ساعة قبل', 'يوم قبل', 'ثلاث أوقات'

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Locale get locale => _locale;
  bool get notificationsEnabled => _notificationsEnabled;
  String get reminderTiming => _reminderTiming;

  // Setter لتغيير اللغة وتخزينها
  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void changeLocale(Locale newLocale) {
    _locale = newLocale;
    notifyListeners();
  }

  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  void setReminderTiming(String timing) {
    _reminderTiming = timing;
    notifyListeners();
  }

  // ====== دعم اختيار اللغة لأول مرة فقط ======

  Future<void> markLanguageSelected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLanguageSelected', true);
  }

  Future<bool> isLanguageAlreadySelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLanguageSelected') ?? false;
  }
}