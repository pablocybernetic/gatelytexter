// lib/screens/home_screen.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gately/models/message_row.dart';
import 'package:gately/services/csv_loader.dart';
import 'package:gately/services/folder_memory.dart';
import 'package:gately/services/license_manager.dart';
import 'package:gately/services/sms_service.dart';
import 'package:gately/widgets/message_table.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MessageRow> _rows = [];
  String _status = 'No CSV imported';
  bool _sending = false;
  final _smsService = SmsService();

  @override
  Widget build(BuildContext context) {
    final license = context.watch<LicenseManager>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Texter Ace'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('assets/logo.png'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildButtons(context, license),
          _buildStatus(),
          Expanded(child: MessageTable(rows: _rows)),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context, LicenseManager license) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _sending ? null : _importCsv,
            icon: const Icon(Icons.file_open),
            label: const Text('Import CSV'),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed:
                (_sending || _rows.isEmpty || license.isExpired)
                    ? null
                    : _sendAll,
            icon: const Icon(Icons.send),
            label: Text('Send (${license.maxPerSession})'),
          ),
          const Spacer(),
          if (license.edition == Edition.free)
            TextButton(
              onPressed: () async {
                // Stub upgrade path
                await license.upgrade();
              },
              child: const Text('Upgrade'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatus() => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  Future<void> _importCsv() async {
    String? initial = await FolderMemory.getPath();
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      initialDirectory: initial,
    );
    if (res == null || res.files.single.path == null) return;
    final path = res.files.single.path!;
    await FolderMemory.setPath(File(path).parent.path);
    setState(() => _status = 'Loading…');
    final rows = await CsvLoader.load(File(path));
    setState(() {
      _rows = rows;
      _status = '${rows.length} rows imported';
    });
  }

  Future<void> _sendAll() async {
    final license = context.read<LicenseManager>();
    if (license.isExpired) {
      setState(() => _status = 'FREE TRIAL EXPIRED');
      return;
    }
    setState(() {
      _sending = true;
      _status = 'Sending…';
    });
    await _smsService.sendAll(
      _rows,
      maxPerSession: license.maxPerSession,
      onStatus: (s) => setState(() => _status = s),
      onDone: (sent, skipped, {bool cancelled = false}) {
        setState(() {
          _sending = false;
          _status =
              'Done. Sent: $sent, Skipped: $skipped${cancelled ? ', Cancelled' : ''}';
        });
      },
      countryCode: '',
    );
  }
}
