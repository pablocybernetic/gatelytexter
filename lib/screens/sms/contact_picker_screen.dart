import 'package:flutter/material.dart';
import 'package:flutter_contacts_service/flutter_contacts_service.dart';

class ContactPickerScreen extends StatefulWidget {
  final List<Contact> contacts;

  const ContactPickerScreen({Key? key, required this.contacts})
    : super(key: key);

  @override
  _ContactPickerScreenState createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  List<Contact> filteredContacts = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredContacts = widget.contacts;
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredContacts = widget.contacts;
      } else {
        filteredContacts =
            widget.contacts.where((contact) {
              final name = contact?.displayName?.toLowerCase() ?? '';
              final phones =
                  contact.phones?.map((p) => p.number ?? '').join(' ') ?? '';
              return name.contains(query.toLowerCase()) ||
                  phones.contains(query);
            }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Contact'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _filterContacts,
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: filteredContacts.length,
        itemBuilder: (context, index) {
          final contact = filteredContacts[index];
          final phoneNumbers = contact.phones ?? [];

          return ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                _getInitials(contact.displayName ?? ''),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(contact.displayName ?? 'Unknown'),
            subtitle: Text('${phoneNumbers.length} number(s)'),
            children:
                phoneNumbers.map((phone) {
                  return ListTile(
                    contentPadding: EdgeInsets.only(left: 72, right: 16),
                    title: Text(phone.number ?? ''),
                    subtitle: Text(phone.label ?? 'Phone'),
                    onTap: () {
                      Navigator.pop(context, {
                        'contact': contact,
                        'phoneNumber': phone.number ?? '',
                      });
                    },
                  );
                }).toList(),
          );
        },
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else {
      return names[0][0].toUpperCase();
    }
  }
}
