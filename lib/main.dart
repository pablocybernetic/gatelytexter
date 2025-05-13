// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gately/screens/home_screen.dart';
import 'package:gately/services/license_manager.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LicenseManager.instance.init();
  await EasyLocalization.ensureInitialized(); // loads saved locale

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('sw'),
        Locale('fr'),
        Locale('sp'),
        Locale('de'),
        Locale('ar'),
        Locale('hd'),
      ],
      path: 'assets/langs',
      fallbackLocale: const Locale('en'),
      saveLocale: true,
      child: const TexterAceApp(),
    ),
  );
}

class TexterAceApp extends StatelessWidget {
  const TexterAceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LicenseManager.instance,
      child: MaterialApp(
        themeMode: ThemeMode.system,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,

        title: 'Texter Ace',
        locale: context.locale, // current locale
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: const HomeScreen(),
      ),
    );
  }
}
