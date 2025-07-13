import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sms_provider.dart';

class SmsComposeScreen extends StatefulWidget {
  @override
  State<SmsComposeScreen> createState() => _SmsComposeScreenState();
}

class _SmsComposeScreenState extends State<SmsComposeScreen> {
  final _controller = TextEditingController();
  final _numberController = TextEditingController();
  int _selectedSim = 0;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SmsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Compose SMS')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _numberController,
              decoration: InputDecoration(labelText: 'Recipient Number'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Message'),
              maxLines: 4,
            ),
            DropdownButton<int>(
              value: _selectedSim,
              items: [
                DropdownMenuItem(value: 0, child: Text('SIM 1')),
                DropdownMenuItem(value: 1, child: Text('SIM 2')),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedSim = val ?? 0;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // await provider.sendMessage(
                //   _numberController.text,
                //   _controller.text,
                //   simSlot: _selectedSim,
                // );
                Navigator.pop(context);
              },
              child: Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
