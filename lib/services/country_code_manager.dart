import 'package:shared_preferences/shared_preferences.dart';

// Not used but kept for reference
class CountryCodeManager {
  static const _key = 'gately_country_code';

  /// returns "+254" or null if not set
  static Future<String?> getCode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key);
  }

  static Future<void> setCode(String code) async {
    final p = await SharedPreferences.getInstance();
    // normalise: keep a single leading +
    code = code.startsWith('+') ? code : '+$code';
    await p.setString(_key, code);
  }
}
