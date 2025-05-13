// lib/util/validators.dart
class Validators {
  static bool isValidNumber(String s) {
    if (s.isEmpty) return false;
    final pattern = RegExp(r'^(\+)?[0-9]+$');
    return pattern.hasMatch(s);
  }
}