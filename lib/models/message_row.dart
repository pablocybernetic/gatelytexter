// lib/models/message_row.dart
import 'package:gately/services/license_manager.dart';

class MessageRow {
  MessageRow({required this.numbers, required this.body, this.status = ''});

  List<String> numbers; // already split & cleaned
  String body; // message text
  String status; // Sent / Waiting / Invalid / …

  /*──────────────── CSV / Excel helper ─────────────────*/
  factory MessageRow.fromCsv(List<String> cols) {
    final raw = cols[0];

    // 1️⃣  split on comma, semicolon, or any whitespace
    final parts =
        raw
            .split(RegExp(r'[;,]'))
            .expand((p) => p.split(RegExp(r'\s+')))
            // 2️⃣  strip “invisible” characters Excel sometimes adds
            .map(
              (s) =>
                  s
                      .replaceAll('\u00A0', '') // non-breaking space
                      .replaceAll('\u200B', '') // zero-width space
                      // ⚠️ keep only ‘+’ or digits – dumps every other char
                      .replaceAll(RegExp(r'[^\d+]'), '')
                      .trim(),
            )
            .where((s) => s.isNotEmpty)
            .toList();

    // 3️⃣  free edition? → keep just one number
    final edition = LicenseManager.instance.edition;
    final nums = edition == Edition.paid ? parts : parts.take(1).toList();

    return MessageRow(
      numbers: nums,
      body: cols.length > 1 ? cols[1].trim() : '',
    );
  }

  /* Optional helper for manual row creation */
  MessageRow.single(String number, String message)
    : numbers = [number.trim()],
      body = message.trim(),
      status = '';
}
