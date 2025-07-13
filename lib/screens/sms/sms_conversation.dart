import 'package:another_telephony/telephony.dart';
import 'package:flutter_contacts_service/flutter_contacts_service.dart';

class SmsConversation {
  final String address;
  final Contact? contact;
  final List<SmsMessage> messages;
  final SmsMessage lastMessage;

  SmsConversation({
    required this.address,
    this.contact,
    required this.messages,
    required this.lastMessage,
  });

  String get displayName {
    if (contact != null &&
        contact!.displayName != null &&
        contact!.displayName!.isNotEmpty) {
      return contact!.displayName!;
    }
    return address;
  }

  String get displayInitials {
    if (contact != null && contact!.displayName != null) {
      final names = contact!.displayName!.split(' ');
      if (names.length >= 2) {
        return '${names[0][0]}${names[1][0]}'.toUpperCase();
      } else if (names.isNotEmpty) {
        return names[0][0].toUpperCase();
      }
    }
    return address.isNotEmpty ? address[0] : '?';
  }

  int get unreadCount => messages.where((msg) => msg.read == false).length;
}
