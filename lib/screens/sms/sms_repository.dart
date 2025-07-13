import 'package:another_telephony/telephony.dart';

class SmsRepository {
  // Simple in-memory storage for now
  List<SmsMessage> _messages = [];

  SmsRepository(); // No parameters needed

  Future<void> saveMessages(List<SmsMessage> messages) async {
    _messages = messages;
  }

  Future<List<SmsMessage>> getMessages() async {
    return _messages;
  }

  Future<List<SmsMessage>> searchMessages(String keyword) async {
    return _messages
        .where(
          (msg) =>
              (msg.body ?? '').toLowerCase().contains(keyword.toLowerCase()) ||
              (msg.address ?? '').toLowerCase().contains(keyword.toLowerCase()),
        )
        .toList();
  }
}
