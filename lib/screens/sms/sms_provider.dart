import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:gately/screens/sms/sms_service.dart';
import 'sms_repository.dart';

class SmsProvider with ChangeNotifier {
  final SmscService smscService;
  final SmsRepository smsRepository;

  List<SmsMessage> _messages = [];
  List<SmsMessage> get messages => _messages;

  bool _loading = false;
  bool get loading => _loading;

  SmsProvider(this.smscService, this.smsRepository);

  Future<void> loadMessages() async {
    _loading = true;
    notifyListeners();

    try {
      _messages =
          await smscService.getAllMessages(); // ← Load both inbox and sent
      await smsRepository.saveMessages(_messages);
    } catch (e) {
      print('Error loading messages: $e');
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> sendMessage(String address, String body, {int? simSlot}) async {
    try {
      await smscService.sendSms(address, body, simSlot: simSlot);
      // Reload messages after sending
      await loadMessages();
    } catch (e) {
      print('Error sending message: $e');
    }
  }
}
