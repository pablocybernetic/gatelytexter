import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
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

  // Database instance
  Database? _database;

  // Platform channel for system SMS operations
  static const MethodChannel _smsChannel = MethodChannel('sms_system_db');

  @override
  void initState() {
    super.initState();
    _initDatabase();
    loadSms();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _database?.close();
    super.dispose();
  }

  // Initialize local database
  Future<void> _initDatabase() async {
    try {
      _database = await openDatabase(
        'sms_backup.db',
        version: 1,
        onCreate: (db, version) {
          return db.execute('''
            CREATE TABLE sms_messages(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              address TEXT NOT NULL,
              body TEXT NOT NULL,
              date INTEGER NOT NULL,
              type INTEGER NOT NULL,
              status TEXT,
              thread_id INTEGER,
              created_at INTEGER NOT NULL
            )
          ''');
        },
      );
    } catch (e) {
      print('Database initialization failed: $e');
    }
  }

  // Save SMS to local database
  Future<void> _saveToLocalDb(
    String address,
    String body,
    int type, {
    String? status,
  }) async {
    if (_database == null) return;

    try {
      await _database!.insert('sms_messages', {
        'address': address,
        'body': body,
        'date': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'status': status ?? 'pending',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Failed to save to local database: $e');
    }
  }

  // Save SMS to system database using platform channel
  Future<bool> _saveToSystemDb(String address, String body, int type) async {
    try {
      final result = await _smsChannel.invokeMethod('insertSms', {
        'address': address,
        'body': body,
        'type': type, // 1 = received, 2 = sent
        'date': DateTime.now().millisecondsSinceEpoch,
        'thread_id': await _getThreadId(address),
      });

      print('SMS saved to system database: $result');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Failed to save to system database: ${e.message}');
      return false;
    } catch (e) {
      print('Error saving to system database: $e');
      return false;
    }
  }

  // Get thread ID for the conversation
  Future<int> _getThreadId(String address) async {
    try {
      // Try to find existing thread ID from previous messages
      final existingMessages = await telephony.getInboxSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
        columns: [SmsColumn.THREAD_ID],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (existingMessages.isNotEmpty &&
          existingMessages.first.threadId != null) {
        return existingMessages.first.threadId!;
      }

      // If no existing thread, create a new one
      return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } catch (e) {
      print('Failed to get thread ID: $e');
      return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
  }

  // Enhanced sendSms method with database storage
  Future<void> sendSms() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      if (!await requestPermissions()) {
        throw Exception('SMS permissions not granted');
      }

      final message = _messageController.text.trim();
      final completer = Completer<void>();

      // Save to local database immediately (as pending)
      await _saveToLocalDb(
        widget.targetNumber,
        message,
        2, // Type 2 for sent messages
        status: 'pending',
      );

      // Save to system database immediately (as default SMS handler)
      final systemSaved = await _saveToSystemDb(
        widget.targetNumber,
        message,
        2,
      );
      if (!systemSaved) {
        print('Warning: Failed to save to system SMS database');
      }

      await telephony.sendSms(
        to: widget.targetNumber,
        message: message,
        isMultipart: true,
        statusListener: (SendStatus status) async {
          // Update local database with delivery status
          await _updateMessageStatus(message, status.toString());

          if (status == SendStatus.SENT) {
            _showSuccessSnackBar('Message sent successfully');
            _messageController.clear();

            // Update local database status
            await _saveToLocalDb(
              widget.targetNumber,
              message,
              2,
              status: 'sent',
            );

            loadSms(); // Refresh messages after actual sending
          } else if (status == SendStatus.DELIVERED) {
            _showSuccessSnackBar('Message delivered');

            // Update local database status
            await _saveToLocalDb(
              widget.targetNumber,
              message,
              2,
              status: 'delivered',
            );
          } else {
            _showErrorSnackBar('Failed to send message: $status');

            // Update local database status
            await _saveToLocalDb(
              widget.targetNumber,
              message,
              2,
              status: 'failed',
            );
          }

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Wait for status callback
      await completer.future.timeout(
        Duration(seconds: 30),
        onTimeout: () async {
          _showErrorSnackBar('Message sending timed out');
          await _updateMessageStatus(message, 'timeout');
        },
      );
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');

      // Update local database with error status
      await _saveToLocalDb(
        widget.targetNumber,
        _messageController.text.trim(),
        2,
        status: 'error: $e',
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  // Update message status in local database
  Future<void> _updateMessageStatus(String messageBody, String status) async {
    if (_database == null) return;

    try {
      await _database!.update(
        'sms_messages',
        {'status': status},
        where: 'body = ? AND address = ? AND type = 2',
        whereArgs: [messageBody, widget.targetNumber],
      );
    } catch (e) {
      print('Failed to update message status: $e');
    }
  }

  // Get messages from local database (optional backup method)
  Future<List<Map<String, dynamic>>> getLocalMessages() async {
    if (_database == null) return [];

    try {
      return await _database!.query(
        'sms_messages',
        where: 'address = ?',
        whereArgs: [widget.targetNumber],
        orderBy: 'date ASC',
      );
    } catch (e) {
      print('Failed to get local messages: $e');
      return [];
    }
  }

  // Existing methods remain the same...
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
      print('getSentSms failed: $e');
      return await _getAlternativeSentMessages();
    }
  }

  Future<List<SmsMessage>> _getAlternativeSentMessages() async {
    try {
      List<SmsMessage> sentMessages = [];

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
