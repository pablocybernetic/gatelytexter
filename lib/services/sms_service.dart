import 'dart:async';
import 'package:another_telephony/telephony.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:gately/models/message_row.dart';
import 'package:gately/util/validators.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  final Telephony _tel = Telephony.instance;
  Completer<void>? _cancelSignal;
  static const MethodChannel _smsHandlerChannel = MethodChannel('sms_handler');
  static const MethodChannel _smsDbChannel = MethodChannel('sms_system_db');

  void cancel() {
    if (_cancelSignal != null && !_cancelSignal!.isCompleted) {
      _cancelSignal!.complete();
    }
  }

  Future<void> sendAll(
    List<MessageRow> rows, {
    String? countryCode,
    required int maxPerSession,
    required void Function(String) onStatus,
    required void Function(int sent, int skipped, {bool cancelled}) onDone,
    void Function()? onRowUpdate,
  }) async {
    _cancelSignal = Completer<void>();
    final smsGranted = await _requestPermissions();
    if (!smsGranted) {
      return;
    }

    final notifGranted = await hasNotificationPermission();
    if (!notifGranted) {
      onStatus('Notification permission denied');
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
            statusListener: (s) async {
              if (s == SendStatus.SENT) {
                row.status = 'Waiting'.tr();
                sent++;
                await _insertSentSms(num, row.body);
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
          skipped++;
          onRowUpdate?.call();
        }

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

  Future<void> _insertSentSms(String address, String body) async {
    try {
      final isDefault = await checkDefaultSmsApp();
      if (!isDefault) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final data = {"address": address, "body": body, "type": 2, "date": now};

      final success = await _smsDbChannel.invokeMethod("insertSms", data);
      if (success == true) {
        print("SMS inserted into system DB.");
      } else {
        print("Failed to insert SMS.");
      }
    } catch (e) {
      print("Insert SMS error: $e");
    }
  }

  String _normalise(String n, String cc) {
    n = n.replaceAll(RegExp(r'[^\d+]'), '');
    if (n.contains('+')) {
      n = '+' + n.replaceAll('+', '');
    }
    if (n.startsWith('+')) return n;
    if (cc.isNotEmpty) {
      if (n.startsWith('0')) n = n.substring(1);
      return '$cc$n';
    }
    const defaultCc = '+254';
    if (!n.startsWith('0') && n.length == 12) return '+$n';
    if (n.startsWith('0')) return '$defaultCc${n.substring(1)}';
    return n;
  }

  Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [Permission.sms, Permission.notification].request();
    return statuses[Permission.sms]?.isGranted ?? false;
  }

  Future<bool> checkDefaultSmsApp() async {
    try {
      final bool isDefault = await _smsHandlerChannel.invokeMethod(
        'isDefaultSmsApp',
      );
      return isDefault;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> promptForDefaultSmsApp() async {
    try {
      await _smsHandlerChannel.invokeMethod('promptDefaultSmsApp');
    } on PlatformException catch (e) {
      print("Default app prompt failed: $e");
    }
  }
}
