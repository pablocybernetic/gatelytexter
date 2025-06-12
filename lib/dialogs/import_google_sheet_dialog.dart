import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gately/services/google_sheet_loader.dart';
import 'package:gately/models/message_row.dart';
import 'package:easy_localization/easy_localization.dart';

Future<T?> showAnimatedSheetDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 800),
    pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (context, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(scale: curved, child: Builder(builder: builder)),
      );
    },
  );
}

Future<void> importFromGoogleSheet({
  required BuildContext context,
  required Function(List<MessageRow>) onImport,
  required Function(String, {List<String> args, Map<String, String> named})
  onStatus,
}) async {
  const sampleUrl =
      'https://docs.google.com/spreadsheets/d/1Q17vPa4NSyU_RoTehwLgGuuC6rgmMpxjPxXrQlYrHPA/edit?usp=sharing';

  final prefs = await SharedPreferences.getInstance();
  final previousLink = prefs.getString('lastGoogleSheetLink');
  final controller = TextEditingController();
  String selectedOption = previousLink != null ? 'previous' : 'sample';

  final selectedUrl = await showAnimatedSheetDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardColor.withOpacity(0.97),
        title: Row(
          children: [
            const Icon(Icons.link, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(
              'choose_google_sheet_source'.tr(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (previousLink == null)
                  RadioListTile<String>(
                    title: Text('use_sample_sheet'.tr()),
                    subtitle: Text(sampleUrl, style: TextStyle(fontSize: 12)),
                    value: 'sample',
                    groupValue: selectedOption,
                    onChanged: (val) => setState(() => selectedOption = val!),
                  ),
                if (previousLink != null)
                  RadioListTile<String>(
                    title: Text('use_previous_sheet'.tr()),
                    subtitle: Text(
                      previousLink,
                      style: TextStyle(fontSize: 12),
                    ),
                    value: 'previous',
                    groupValue: selectedOption,
                    onChanged: (val) => setState(() => selectedOption = val!),
                  ),
                RadioListTile<String>(
                  title: Text('use_new_link'.tr()),
                  value: 'new',
                  groupValue: selectedOption,
                  onChanged: (val) => setState(() => selectedOption = val!),
                ),
                if (selectedOption == 'new')
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Padding(
                      key: const ValueKey("new_field"),
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText:
                              'https://docs.google.com/spreadsheets/d/...',
                          hintStyle: TextStyle(
                            color: Colors.grey.withOpacity(0.3),
                            fontStyle: FontStyle.italic,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('cancel_btn'.tr()),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_download),
            label: Text('import_google_sheet'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              String chosenUrl;
              if (selectedOption == 'new') {
                chosenUrl = controller.text.trim();
              } else if (selectedOption == 'previous') {
                chosenUrl = previousLink!;
              } else {
                chosenUrl = sampleUrl;
              }
              Navigator.of(context).pop(chosenUrl);
            },
          ),
        ],
      );
    },
  );

  if (selectedUrl == null || selectedUrl.isEmpty) return;

  onStatus('status_loading');
  try {
    final rows = await GoogleSheetLoader.loadFromUrl(selectedUrl);
    onImport(rows);
    onStatus('status_rows', args: ['${rows.length}'], named: const {});

    if (selectedUrl != sampleUrl) {
      await prefs.setString('lastGoogleSheetLink', selectedUrl);
    }

    Fluttertoast.showToast(
      msg: 'import_success'.tr(namedArgs: {'count': '${rows.length}'}),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  } catch (e) {
    onStatus('status_none');
    Fluttertoast.showToast(
      msg: e.toString().replaceFirst('Exception: ', ''),
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.redAccent,
      textColor: Colors.white,
    );
  }
}
