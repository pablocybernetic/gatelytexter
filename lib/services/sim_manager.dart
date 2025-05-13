import 'package:shared_preferences/shared_preferences.dart';

class SimManager {
  static const _key = 'gately_sim_slot'; // -1 = ask each time

  static Future<int?> getSim() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_key); // null means not set yet
  }

  static Future<void> setSim(int slot) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_key, slot); // 0,1, or -1
  }
}
