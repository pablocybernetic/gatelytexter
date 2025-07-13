import 'package:another_telephony/telephony.dart';

class SmsPermissionHandler {
  final Telephony _telephony = Telephony.instance;

  Future<bool> requestPermissions() async {
    return await _telephony.requestPhoneAndSmsPermissions ?? false;
  }
}
