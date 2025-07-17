import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class SmsViewtest extends StatefulWidget {
  final String targetNumber;

  const SmsViewtest({super.key, required this.targetNumber});

  @override
  State<SmsViewtest> createState() => _SmsViewtestState();
}

class _SmsViewtestState extends State<SmsViewtest> {
  final Telephony telephony = Telephony.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<SmsMessage> allMessages = [];
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    loadSms();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> requestPermissions() async {
    final smsStatus = await Permission.sms.request();
    final phoneStatus = await Permission.phone.request();

    if (smsStatus.isGranted && phoneStatus.isGranted) return true;

    if (smsStatus.isPermanentlyDenied || phoneStatus.isPermanentlyDenied) {
      await openAppSettings();
    }
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

    try {
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
    } catch (e) {
      // If getSentSms fails, try alternative approach
      print('getSentSms failed: $e');
      return await _getAlternativeSentMessages();
    }
  }

  Future<List<SmsMessage>> _getAlternativeSentMessages() async {
    try {
      // Try to get messages from different SMS folders
      List<SmsMessage> sentMessages = [];

      // Try getting from outbox
      try {
        final outboxMessages = await telephony.getSentSms(
          filter: SmsFilter.where(
            SmsColumn.ADDRESS,
          ).equals(widget.targetNumber),
          columns: [
            SmsColumn.ADDRESS,
            SmsColumn.BODY,
            SmsColumn.DATE,
            SmsColumn.TYPE,
          ],
        );
        sentMessages.addAll(outboxMessages);
      } catch (e) {
        print('Outbox query failed: $e');
      }

      // Try getting from draft
      try {
        final draftMessages = await telephony.getDraftSms(
          filter: SmsFilter.where(
            SmsColumn.ADDRESS,
          ).equals(widget.targetNumber),
          columns: [
            SmsColumn.ADDRESS,
            SmsColumn.BODY,
            SmsColumn.DATE,
            SmsColumn.TYPE,
          ],
        );
        sentMessages.addAll(draftMessages);
      } catch (e) {
        print('Draft query failed: $e');
      }

      return sentMessages;
    } catch (e) {
      print('Alternative sent messages failed: $e');
      return [];
    }
  }

  Future<void> loadSms() async {
    setState(() => _isLoading = true);

    try {
      final inboxMessages = await getInbox();
      final sentMessages = await getSent();

      final combined = [...inboxMessages, ...sentMessages];
      combined.sort((a, b) => (a.date ?? 0).compareTo(b.date ?? 0));

      setState(() {
        allMessages = combined;
        _isLoading = false;
      });

      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load messages: $e');
    }
  }

  Future<void> sendSms() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      if (!await requestPermissions()) {
        throw Exception('SMS permissions not granted');
      }

      final message = _messageController.text.trim();
      final completer = Completer<void>();

      await telephony.sendSms(
        to: widget.targetNumber,
        message: message,
        isMultipart: true,
        statusListener: (SendStatus status) {
          if (status == SendStatus.SENT) {
            _showSuccessSnackBar('Message sent successfully');
            _messageController.clear();
            loadSms(); // Refresh messages after actual sending
          } else if (status == SendStatus.DELIVERED) {
            _showSuccessSnackBar('Message delivered');
          } else {
            _showErrorSnackBar('Failed to send message: $status');
          }

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Wait for status callback
      await completer.future.timeout(
        Duration(seconds: 30),
        onTimeout: () {
          _showErrorSnackBar('Message sending timed out');
        },
      );
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget buildBubble(SmsMessage sms) {
    bool isSent = sms.type == SmsType.MESSAGE_TYPE_SENT;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color:
                isSent
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(isSent ? 20 : 4),
              bottomRight: Radius.circular(isSent ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                sms.body ?? '',
                style: TextStyle(
                  fontSize: 16,
                  color:
                      isSent
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 6),
              Text(
                sms.date != null
                    ? _formatTime(
                      DateTime.fromMillisecondsSinceEpoch(sms.date!),
                    )
                    : '',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isSent
                          ? Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.7)
                          : Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : sendSms,
                icon:
                    _isSending
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                        : Icon(
                          Icons.send_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.targetNumber,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              '${allMessages.length} messages',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : loadSms,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading messages...',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                    : allMessages.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.3),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start a conversation by sending a message',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: loadSms,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemCount: allMessages.length,
                        itemBuilder: (context, index) {
                          return buildBubble(allMessages[index]);
                        },
                      ),
                    ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}
