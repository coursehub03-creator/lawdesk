import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as app;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'screen/language_selector_screen.dart';
import 'screen/notification_screen.dart';
import 'screen/pin_login_screen.dart';
import 'screen/client_list_screen.dart';
import 'screen/add_client_screen.dart';
import 'screen/settings_screen.dart';
import 'core/settings_provider.dart' as app;
import 'database/db_helper.dart';
import 'core/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة قاعدة البيانات لأنظمة سطح المكتب
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await DBHelper.database;

  // تهيئة Supabase
  await Supabase.initialize(
    url: 'https://prslxygnoyokesfhtjbb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByc2x4eWdub3lva2VzZmh0amJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgxMDA0MzksImV4cCI6MjA2MzY3NjQzOX0.jQVBND4jFq8a5CyHSzTzeg-odV7q_fJkhDdT1B5QxFY',
  );

  // المزامنة الكاملة أول مرة
  await SyncService.syncAll();

  // 🔥 تشغيل مراقبة الاتصال بالإنترنت
  Connectivity().onConnectivityChanged.listen((result) async {
    if (result != ConnectivityResult.none) {
      await SyncService.syncAll();
    }
  });

  runApp(
    app.ChangeNotifierProvider(
      create: (_) => app.SettingsProvider(),
      child: const LawDeskApp(),
    ),
  );
}

class LawDeskApp extends StatelessWidget {
  const LawDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = app.Provider.of<app.SettingsProvider>(context);

    return MaterialApp(
      title: 'LawDesk',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Global background image for all screens.
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Opacity(
                  opacity: 0.14,
                  child: Image.asset(
                    'assets/images/logo_background.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            if (child != null) child,
          ],
        );
      },
      themeMode: settingsProvider.themeMode,
      locale: settingsProvider.locale,
      supportedLocales: const [Locale('ar'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white10,
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF0F1D2F),
        cardColor: const Color(0xFF1C2A3A),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1C2A3A),
          hintStyle: TextStyle(color: Colors.white54),
        ),
      ),
      home: const LanguageSelectorScreen(),
      routes: {
        '/notifications': (context) => const NotificationScreen(),
        '/login': (context) => const PinLoginScreen(),
        '/clients': (context) => const ClientListScreen(),
        '/add-client': (context) => const AddClientScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
