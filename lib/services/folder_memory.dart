// lib/services/folder_memory.dart
import 'package:shared_preferences/shared_preferences.dart';

class FolderMemory {
  static const _key = 'lastFolderPath';
  static Future<void> setPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }
  static Future<String?> getPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}