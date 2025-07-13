import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sms_provider.dart';

class SmsThreadScreen extends StatefulWidget {
  final dynamic threadId;
  final String? address; // Add this if you want to pass address as a fallback

  const SmsThreadScreen({Key? key, required this.threadId, this.address})
    : super(key: key);

  @override
  State<SmsThreadScreen> createState() => _SmsThreadScreenState();
}

class _SmsThreadScreenState extends State<SmsThreadScreen> {
  @override
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SmsProvider>(context);

    // Print ALL loaded messages (for debugging)
    print('--- ALL loaded messages (${provider.messages.length}) ---');
    for (var msg in provider.messages) {
      print(
        'address: ${msg.address}, threadId: ${msg.threadId} (${msg.threadId.runtimeType}), body: ${msg.body}, type: ${msg.type}',
      );
    }

    // Print all unique threadIds and their counts
    final threadIdMap = <String, int>{};
    for (var msg in provider.messages) {
      final key = msg.threadId?.toString() ?? 'null';
      threadIdMap[key] = (threadIdMap[key] ?? 0) + 1;
    }
    print('--- Unique threadIds:');
    threadIdMap.forEach((k, v) => print('threadId: $k -> count: $v'));

    // Print all unique addresses and their counts
    final addressMap = <String, int>{};
    for (var msg in provider.messages) {
      final key = msg.address ?? 'null';
      addressMap[key] = (addressMap[key] ?? 0) + 1;
    }
    print('--- Unique addresses:');
    addressMap.forEach((k, v) => print('address: $k -> count: $v'));

    // Filtering by threadId (always as String for safety)
    print(
      '--- Filtering for threadId=${widget.threadId} (${widget.threadId.runtimeType}) ---',
    );
    final threadKey = widget.threadId?.toString();
    List messages =
        provider.messages
            .where((msg) => msg.threadId?.toString() == threadKey)
            .toList();

    print(
      'Filtered by threadId: $threadKey, found ${messages.length} messages.',
    );

    // If no messages, try fallback by address
    if (messages.isEmpty && widget.address != null) {
      print(
        'No messages matched threadId. Trying fallback by address: ${widget.address}',
      );
      messages =
          provider.messages
              .where((msg) => msg.address == widget.address)
              .toList();
      print(
        'Filtered by address: ${widget.address}, found ${messages.length} messages.',
      );
    }

    print('---- Final messages list (${messages.length}) ----');
    for (var m in messages) {
      print('Msg: "${m.body}", threadId: ${m.threadId}, address: ${m.address}');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Conversation ${widget.threadId}, Messages: ${messages.length}',
        ),
      ),
      body:
          messages.isEmpty
              ? Center(child: Text('No messages found for this thread.'))
              : ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.type == 2; // 2 = sent, 1 = received
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[100] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(msg.body ?? ''),
                    ),
                  );
                },
              ),
    );
  }
}
