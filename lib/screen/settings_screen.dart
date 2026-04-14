import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> reminderOptions = [
    'ساعة قبل',
    '12 ساعة قبل',
    'يوم قبل',
    'ثلاث أوقات'
  ];

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = settingsProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // تم إزالة تسجيل الدخول بجوجل

          ListTile(
            title: const Text('اللغة'),
            trailing: DropdownButton<Locale>(
              value: settingsProvider.locale,
              items: const [
                DropdownMenuItem(value: Locale('ar'), child: Text('العربية')),
                DropdownMenuItem(value: Locale('fr'), child: Text('Français')),
              ],
              onChanged: (locale) {
                if (locale != null) {
                  settingsProvider.changeLocale(locale);
                }
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('الوضع المظلم'),
            value: isDark,
            onChanged: settingsProvider.toggleTheme,
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('تفعيل التنبيهات'),
            value: settingsProvider.notificationsEnabled,
            onChanged: settingsProvider.toggleNotifications,
            secondary: const Icon(Icons.notifications_active),
          ),
          if (settingsProvider.notificationsEnabled)
            ListTile(
              title: const Text('وقت التذكير المسبق'),
              subtitle: DropdownButton<String>(
                isExpanded: true,
                value: settingsProvider.reminderTiming,
                items: reminderOptions.map((option) {
                  return DropdownMenuItem(value: option, child: Text(option));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    settingsProvider.setReminderTiming(value);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}