import 'package:flutter/material.dart';
import 'package:gately/screens/sms/test.dart';
import 'package:provider/provider.dart';
import 'sms_provider.dart';
import 'sms_compose_screen.dart';
import 'sms_search_delegate.dart';
// import 'package:telephony/telephony.dart';

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
      try {
        Provider.of<SmsProvider>(context, listen: false).loadMessages();
        print("Called loadMessages() in initState.");
      } catch (e, stack) {
        print('Error calling loadMessages in initState: $e\n$stack');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SmsProvider>(context);

    // --- Group messages by address for threads view ---
    final threads = <String, Map<String, dynamic>>{};
    try {
      for (final msg in provider.messages) {
        final key = msg.address ?? '';
        // Only keep the latest message per address
        if (!threads.containsKey(key) ||
            (msg.date ?? 0) > (threads[key]?['msg']?.date ?? 0)) {
          threads[key] = {'msg': msg, 'count': 1};
        } else {
          threads[key]!['count'] = threads[key]!['count'] + 1;
        }
      }
    } catch (e, stack) {
      print('Error grouping threads: $e\n$stack');
    }
    final threadList = threads.values.map((t) => t['msg'] as dynamic).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('SMS Conversations'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              try {
                provider.loadMessages();
                print("Reloading messages via refresh button.");
              } catch (e, stack) {
                print('Error on refresh: $e\n$stack');
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              try {
                showSearch(
                  context: context,
                  delegate: SmsSearchDelegate(provider),
                );
              } catch (e, stack) {
                print('Error launching search: $e\n$stack');
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: () {
              // Toggle theme logic
              print("Theme toggle pressed.");
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
                      onPressed: () {
                        try {
                          provider.loadMessages();
                          print("Reloading messages via 'Refresh' button.");
                        } catch (e, stack) {
                          print('Error on refresh button: $e\n$stack');
                        }
                      },
                      child: Text('Refresh'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: threadList.length,
                itemBuilder: (context, index) {
                  final msg = threadList[index];
                  return ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text(msg.address ?? 'Unknown'),
                    subtitle: Text(
                      msg.body ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatDate(
                        msg.date != null
                            ? DateTime.fromMillisecondsSinceEpoch(msg.date!)
                            : null,
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      try {
                        print(
                          "Tapped on thread address: ${msg.address}. Opening conversation.",
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => SmsViewtest(targetNumber: msg.address),
                          ),
                        );
                      } catch (e, stack) {
                        print(
                          'Error navigating to SingleConversationScreen: $e\n$stack',
                        );
                      }
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          try {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SmsComposeScreen()),
            );
            print("Navigating to compose screen.");
          } catch (e, stack) {
            print('Error navigating to compose screen: $e\n$stack');
          }
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

class SingleConversationScreen extends StatelessWidget {
  final String? address;
  const SingleConversationScreen({Key? key, required this.address})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SmsProvider>(context);

    // Show loading spinner while fetching messages
    if (provider.loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Conversation: ${address ?? "Unknown"}')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Continue as before with your filtering/matching...
    List<dynamic> messages = [];
    try {
      print('Filtering messages for address: $address');
      print(provider.messages);
      messages =
          provider.messages.where((msg) => msg.address == address).toList()
            ..sort((a, b) => (b.date ?? 0).compareTo(a.date ?? 0));
      print('Matched ${messages.length} messages for conversation $address.');
      for (final m in messages) {
        print('Message: ${m.body}, address: ${m.address}');
      }
    } catch (e, stack) {
      print('Error filtering conversation messages: $e\n$stack');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Conversation: ${address ?? "Unknown"} (${messages.length})',
        ),
      ),
      body:
          messages.isEmpty
              ? Center(child: Text('No messages for this conversation.'))
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
