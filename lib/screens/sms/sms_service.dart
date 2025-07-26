import 'package:another_telephony/telephony.dart';
import 'package:flutter/services.dart';

class SmscService {
  final Telephony telephony = Telephony.instance;

  static const MethodChannel _smsDbChannel = MethodChannel("sms_system_db");
  static const MethodChannel _smsHandlerChannel = MethodChannel("sms_handler");

  Future<bool> requestPermissions() async {
    try {
      final bool? permissionsGranted =
          await telephony.requestPhoneAndSmsPermissions;
      return permissionsGranted ?? false;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  Future<bool> isDefaultSmsApp() async {
    try {
      final bool result = await _smsHandlerChannel.invokeMethod(
        "isDefaultSmsApp",
      );
      print("✅ Default SMS app status: $result");
      return result;
    } catch (e) {
      print('❌ Error checking default SMS app: $e');
      return false;
    }
  }

  Future<void> sendSms(String address, String body) async {
    try {
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        throw Exception('SMS permissions not granted');
      }

      await telephony.sendSms(
        to: address,
        message: body,
        isMultipart: body.length > 160,
      );

      print('📨 SMS sent to $address');

      final isDefault = await isDefaultSmsApp();
      if (!isDefault) {
        print("⚠️ Not default SMS app — skipping DB insert.");
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final Map<String, dynamic> data = {
        "address": address,
        "body": body,
        "type": 2, // 2 = SENT, per Android Telephony
        "date": now,
        "thread_id": null,
      };

      print("📥 Attempting to save SMS to system DB via platform channel...");
      final result = await _smsDbChannel.invokeMethod("insertSms", data);

      print("📦 Result from native insert: $result");
      if (result == true) {
        print("✅ SMS saved to system database.");
      } else {
        print("❌ Failed to save SMS to system DB (insertSms returned false).");
      }
    } catch (e, stack) {
      print("🔥 Exception during sendSms: $e");
      print(stack);
    }
  }

  Future<List<SmsMessage>> getInbox() async {
    try {
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        throw Exception('SMS permissions not granted');
      }

      final messages = await telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.THREAD_ID,
        ],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      print('Retrieved ${messages.length} inbox messages');
      return messages;
    } catch (e) {
      print('Error getting inbox: $e');
      return [];
    }
  }

  Future<List<SmsMessage>> getSentMessages() async {
    try {
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        print("SmscService: NO PERMISSIONS for Sent");
      }

      final messages = await telephony.getSentSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.THREAD_ID,
        ],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      print('Retrieved ${messages.length} sent messages');
      return messages;
    } catch (e) {
      print('Error getting sent messages: $e');
      return [];
    }
  }

  Future<List<SmsMessage>> getAllMessages() async {
    try {
      final inbox = await getInbox();
      final sent = await getSentMessages();

      final allMessages = [...inbox, ...sent];
      allMessages.sort((a, b) => (b.date ?? 0).compareTo(a.date ?? 0));
      print('Total messages: ${allMessages.length}');
      return allMessages;
    } catch (e) {
      print('Error getting all messages: $e');
      return [];
    }
  }

  Future<int> _getThreadId(String address) async {
    try {
      final messages = await telephony.getInboxSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
        columns: [SmsColumn.THREAD_ID],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (messages.isNotEmpty && messages.first.threadId != null) {
        return messages.first.threadId!;
      }
    } catch (e) {
      print("Error retrieving thread ID: $e");
    }

    // fallback
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}
