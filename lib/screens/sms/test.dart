import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsViewtest extends StatefulWidget {
  final String targetNumber;

  const SmsViewtest({super.key, required this.targetNumber});

  @override
  State<SmsViewtest> createState() => _SmsViewtestState();
}

class _SmsViewtestState extends State<SmsViewtest> {
  final Telephony telephony = Telephony.instance;
  List<SmsMessage> allMessages = [];

  @override
  void initState() {
    super.initState();
    loadSms();
  }

  Future<bool> requestPermissions() async {
    final status = await Permission.sms.request();
    if (status.isGranted) return true;
    await openAppSettings();
    return false;
  }

  Future<List<SmsMessage>> getInbox() async {
    if (!await requestPermissions()) return [];
    return await telephony.getInboxSms(
      filter: SmsFilter.where(SmsColumn.ADDRESS).equals(widget.targetNumber),
      columns: [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
        SmsColumn.TYPE,
      ],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
  }

  Future<List<SmsMessage>> getSent() async {
    if (!await requestPermissions()) return [];
    return await telephony.getSentSms(
      filter: SmsFilter.where(SmsColumn.ADDRESS).equals(widget.targetNumber),
      columns: [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
        SmsColumn.TYPE,
      ],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
  }

  Future<void> loadSms() async {
    final inboxMessages = await getInbox();
    final sentMessages = await getSent();

    final combined = [...inboxMessages, ...sentMessages];
    combined.sort((a, b) => (a.date ?? 0).compareTo(b.date ?? 0));

    setState(() {
      allMessages = combined;
    });
  }

  Widget buildBubble(SmsMessage sms) {
    // Most likely an enum:
    bool isSent = sms.type == SmsType.MESSAGE_TYPE_SENT;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isSent ? Colors.green[200] : Colors.grey[300],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(isSent ? 16 : 0),
              bottomRight: Radius.circular(isSent ? 0 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                sms.body ?? '',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 6),
              Text(
                sms.date != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                      sms.date!,
                    ).toLocal().toString().split('.')[0]
                    : '',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.targetNumber}')),
      body: RefreshIndicator(
        onRefresh: loadSms,
        child: ListView.builder(
          padding: EdgeInsets.all(8),
          itemCount: allMessages.length,
          itemBuilder: (context, index) {
            return buildBubble(allMessages[index]);
          },
        ),
      ),
    );
  }
}
