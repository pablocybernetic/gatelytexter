// lib/services/license_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// “Free” → trial-mode with quota / expiry
/// “Paid” → unlimited (after a successful in-app purchase)
enum Edition { free, paid }

class LicenseManager extends ChangeNotifier {
  /* ── singleton ─────────────────────────────────────────────── */
  static final LicenseManager instance = LicenseManager._();
  LicenseManager._();

  /* ── preference keys ───────────────────────────────────────── */
  static const _installKey = 'installDate';
  static const _editionKey = 'edition';

  /* ── stored state ──────────────────────────────────────────── */
  late DateTime _installDate;
  late Edition _edition;

  /* ── public getters ────────────────────────────────────────── */
  Edition get edition => _edition;
  Duration get age => DateTime.now().difference(_installDate);
  int get maxPerSession => _edition == Edition.paid ? 500 : 10;
  bool get isExpired =>
      _edition == Edition.free && age > const Duration(days: 30);

  /* ── initialise from SharedPreferences ─────────────────────── */
  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();

    // first-run → save install timestamp
    final ts = sp.getInt(_installKey);
    if (ts == null) {
      _installDate = DateTime.now();
      await sp.setInt(_installKey, _installDate.millisecondsSinceEpoch);
    } else {
      _installDate = DateTime.fromMillisecondsSinceEpoch(ts);
    }

    // last saved edition (default = free)
    _edition = Edition.values[sp.getInt(_editionKey) ?? 0];
  }

  /* ── upgrade helpers ───────────────────────────────────────── */
  /// Call this from `PurchaseService` once a purchase is verified.
  Future<void> grantPaid() async {
    _edition = Edition.paid;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_editionKey, _edition.index);
    notifyListeners();
  }

  /// Alias kept for older UI / code – just forwards to [grantPaid].
  Future<void> setPaid() => grantPaid();

  /// Another alias (what older builds called from the UI).
  Future<void> upgrade() => grantPaid();
}
