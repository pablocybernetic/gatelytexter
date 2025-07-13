import 'package:another_telephony/telephony.dart';

class SmscService {
  final Telephony telephony = Telephony.instance;

  Future<bool> requestPermissions() async {
    try {
      // Use telephony's built-in permission request
      final bool? permissionsGranted =
          await telephony.requestPhoneAndSmsPermissions;
      return permissionsGranted ?? false;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<List<SmsMessage>> getInbox() async {
    try {
      // Request permissions first using telephony
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        throw Exception('SMS permissions not granted');
      }

      // Get inbox messages
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
        throw Exception('SMS permissions not granted');
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

  Future<void> sendSms(String address, String body, {int? simSlot}) async {
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

      print('SMS sent to $address');
    } catch (e) {
      print('Error sending SMS: $e');
      rethrow;
    }
  }
}
