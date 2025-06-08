// lib/main.dart
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gately/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:gately/services/license_manager.dart';
import 'package:gately/services/purchase_service.dart'; // <-- NEW
import 'package:gately/screens/home_screen.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await LicenseManager.instance.grantPaid(); // unlock premium locally
  // 🔔 local-notification init
  await Notifier.instance.init();

  /// initialise the two singletons
  await LicenseManager.instance.init();
  final purchaseService = PurchaseService(); // <── create
  await purchaseService.init(); // <── connect to store

  await EasyLocalization.ensureInitialized();

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
      child: MyApp(purchase: purchaseService), // <── pass down
    ),
  );
  // Fluttertoast.showToast(msg: 'Test Toast');
  // Show a test toast to verify everything is working
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.purchase});
  final PurchaseService purchase;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: LicenseManager.instance),
        Provider.value(value: purchase), // <── make it reachable
      ],
      child: MaterialApp(
        themeMode: ThemeMode.system,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: const HomeScreen(), // ctor now param-less
      ),
    );
  }
}
