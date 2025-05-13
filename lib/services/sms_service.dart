import 'dart:async';

import 'package:another_telephony/telephony.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:gately/models/message_row.dart';
import 'package:gately/util/validators.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  final Telephony _tel = Telephony.instance;
  Completer<void>? _cancelSignal;

  void cancel() {
    if (_cancelSignal != null && !_cancelSignal!.isCompleted) {
      _cancelSignal!.complete();
    }
  }

  Future<void> sendAll(
    List<MessageRow> rows, {
    String? countryCode, // ← Now optional
    required int maxPerSession,
    required void Function(String) onStatus,
    required void Function(int sent, int skipped, {bool cancelled}) onDone,
    void Function()? onRowUpdate,
  }) async {
    _cancelSignal = Completer<void>();

    if (!await _requestPermissions()) {
      onStatus('SMS permission denied');
      return;
    }

    int sent = 0, skipped = 0;
    bool cancelled = false;

    outerLoop:
    for (final row in rows) {
      if (_cancelSignal!.isCompleted) {
        cancelled = true;
        break;
      }
      if (sent >= maxPerSession) {
        onStatus('LIMIT REACHED');
        break;
      }

      if (row.body.trim().isEmpty) {
        row.status = 'Skipped'.tr();
        onRowUpdate?.call();
        skipped++;
        continue;
      }

      for (var num in row.numbers) {
        if (_cancelSignal!.isCompleted) {
          cancelled = true;
          break outerLoop;
        }

        // normalize number if needed
        num = _normalise(num, countryCode ?? '');

        if (!Validators.isValidNumber(num)) {
          row.status = 'Invalid'.tr();
          skipped++;
          onRowUpdate?.call();
          continue;
        }
        if (sent >= maxPerSession) break outerLoop;

        try {
          final completer = Completer<void>();

          await _tel.sendSms(
            to: num,
            message: row.body,
            isMultipart: true,
            statusListener: (s) {
              if (s == SendStatus.SENT) {
                row.status = 'Waiting'.tr();
                sent++;
              } else if (s == SendStatus.DELIVERED) {
                row.status = 'Delivered'.tr();
              } else {
                row.status = 'Failed($s)'.tr();
                skipped++;
              }
              onRowUpdate?.call();
              if (!completer.isCompleted) completer.complete();
            },
          );

          await Future.any([completer.future, _cancelSignal!.future]);
          if (_cancelSignal!.isCompleted) {
            cancelled = true;
            break outerLoop;
          }

          onStatus('Sent $sent / $maxPerSession');
        } catch (e) {
          row.status = 'Failed(${e.runtimeType})';
          onStatus('Err: $e');
          print('Generic error $e');
          skipped++;
          onRowUpdate?.call();
        }

        // throttle
        await Future.any([
          Future.delayed(const Duration(seconds: 3)),
          _cancelSignal!.future,
        ]);
        if (_cancelSignal!.isCompleted) {
          cancelled = true;
          break outerLoop;
        }
      }
    }

    onDone(sent, skipped, cancelled: cancelled);
    _cancelSignal = null;
  }

  /* utils ------------------------------------------------------------ */

  String _normalise(String n, String cc) {
    n = n.replaceAll(RegExp(r'\s+'), '');
    if (n.startsWith('+')) return n;
    if (n.startsWith('0')) n = n.substring(1);
    return '$cc$n'; // "+254" + "712..." -> "+254712..."
  }

  Future<bool> _requestPermissions() async {
    // request SEND_SMS + READ_PHONE_STATE in one go
    final statuses =
        await [
          Permission.sms,
          Permission.phone, // = READ_PHONE_STATE
        ].request();

    return statuses[Permission.sms]!.isGranted &&
        statuses[Permission.phone]!.isGranted;
  }
}
