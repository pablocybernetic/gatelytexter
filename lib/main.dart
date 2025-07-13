import 'package:flutter/material.dart';
import 'package:gately/services/notification_service.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
import 'package:gately/services/license_manager.dart';
import 'package:gately/services/purchase_service.dart';
import 'package:gately/screens/home_screen.dart';
import 'package:easy_localization/easy_localization.dart';

// Import your SMS feature classes:
import 'package:gately/screens/sms/sms_provider.dart';
import 'package:gately/screens/sms/sms_repository.dart';

import 'screens/sms/sms_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.instance.init();
  await LicenseManager.instance.init();
  final purchaseService = PurchaseService();
  await purchaseService.init();
  await EasyLocalization.ensureInitialized();

  // TODO: Initialize your DB instance here (Isar, sqflite, etc.)
  // final isar = await Isar.open(...);

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('sw'),
        Locale('fr'),
        Locale('de'),
        Locale('ar'),
      ],
      path: 'assets/langs',
      fallbackLocale: const Locale('en'),
      saveLocale: true,
      child: MyApp(
        purchase: purchaseService,
        // isar: isar, // pass your db instance if needed
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.purchase,
    // required this.isar, // if you use a db instance
  });

  final PurchaseService purchase;
  // final Isar isar; // if you use Isar

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: LicenseManager.instance),
        Provider.value(value: purchase),
        ChangeNotifierProvider(
          create: (_) => SmsProvider(SmscService(), SmsRepository()),
        ),
      ],
      child: MaterialApp(
        themeMode: ThemeMode.system,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: const HomeScreen(),
      ),
    );
  }
}
