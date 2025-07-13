import 'package:flutter/material.dart';
import 'sms_provider.dart';

class SmsSearchDelegate extends SearchDelegate {
  final SmsProvider provider;

  SmsSearchDelegate(this.provider);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => BackButton();

  @override
  Widget buildResults(BuildContext context) {
    final results =
        provider.messages
            .where(
              (msg) =>
                  (msg.body ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (msg.address ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final msg = results[index];
        return ListTile(
          title: Text(msg.address ?? ''),
          subtitle: Text(msg.body ?? ''),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
