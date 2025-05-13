// lib/services/license_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Edition { free, paid }

class LicenseManager extends ChangeNotifier {
  static final LicenseManager instance = LicenseManager._();
  LicenseManager._();

  static const _installKey = 'installDate';
  static const _editionKey = 'edition';

  late DateTime _installDate;
  late Edition _edition;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_installKey);
    if (ts == null) {
      _installDate = DateTime.now();
      await prefs.setInt(_installKey, _installDate.millisecondsSinceEpoch);
    } else {
      _installDate = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    _edition = Edition.values[prefs.getInt(_editionKey) ?? 0];
  }

  Edition get edition => _edition;
  Duration get age => DateTime.now().difference(_installDate);

  int get maxPerSession => _edition == Edition.paid ? 500 : 47;
  bool get isExpired =>
      _edition == Edition.free && age > const Duration(days: 30);

  Future<void> upgrade() async {
    _edition = Edition.paid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_editionKey, _edition.index);
    notifyListeners();
  }
}
