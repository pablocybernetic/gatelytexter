import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sms_provider.dart';
import 'sms_thread_screen.dart';
import 'sms_compose_screen.dart';
import 'sms_search_delegate.dart';

class SmsScreen extends StatefulWidget {
  @override
  _SmsScreenState createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  @override
  void initState() {
    super.initState();
    // Load messages when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SmsProvider>(context, listen: false).loadMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SmsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('SMS Conversations'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => provider.loadMessages(),
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SmsSearchDelegate(provider),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: () {
              // Toggle theme logic
            },
          ),
        ],
      ),
      body:
          provider.loading
              ? Center(child: CircularProgressIndicator())
              : provider.messages.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sms_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No messages found'),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => provider.loadMessages(),
                      child: Text('Refresh'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: provider.messages.length,
                itemBuilder: (context, index) {
                  final msg = provider.messages[index];
                  final hasThread = msg.threadId != null;
                  return ListTile(
                    title: Text(msg.address ?? 'Unknown'),
                    subtitle: Text(msg.body ?? ''),
                    trailing: Text(
                      _formatDate(
                        msg.date != null
                            ? DateTime.fromMillisecondsSinceEpoch(msg.date!)
                            : null,
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      if (hasThread) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => SmsThreadScreen(threadId: msg.threadId!),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('This message has no thread ID.'),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SmsComposeScreen()),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inMinutes}m ago';
    }
  }
}
