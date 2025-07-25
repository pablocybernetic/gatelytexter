// lib/screens/home_screen.dart
import 'dart:io';
import 'dart:ui';

import 'package:android_intent_plus/android_intent.dart';
import 'package:another_telephony/telephony.dart';
import 'package:gately/dialogs/import_google_sheet_dialog.dart';
import 'package:gately/services/notification_service.dart';
import 'package:gately/services/purchase_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gately/models/message_row.dart';
import 'package:gately/services/country_code_manager.dart';
import 'package:gately/services/csv_loader.dart';
import 'package:gately/services/folder_memory.dart';
import 'package:gately/services/license_manager.dart';
import 'package:gately/services/sms_service.dart';
import 'package:gately/widgets/message_table.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'sms/sms_provider.dart';
import 'sms/sms_repository.dart';
import 'sms/sms_screen.dart';
import 'sms/sms_service.dart';

/*──────────────────────── brand / theme palette ─────────────────────────*/
class _P {
  /* brand hues */
  static const _pinkL = Color(0xFFFAD2DF);
  static const _pinkD = Color(0xFF954F63);
  static const _blueL = Color(0xFF82E6FF);
  static const _blueD = Color(0xFF339DC0);
  static const _orangeL = Color(0xFFF88062);
  static const _orangeD = Color(0xFFB84E35);

  static Brightness _b(BuildContext c) => Theme.of(c).brightness;
  static bool _dark(BuildContext c) => _b(c) == Brightness.dark;

  /* page backgrounds */
  static Color bg(BuildContext c) =>
      _dark(c)
          ? const Color(0xFF101314)
          : const Color.fromARGB(255, 255, 255, 255);

  /* drawer specific: strictly monochrome */
  static Color drawerBg(BuildContext c) =>
      _dark(c) ? Colors.black : Colors.white;
  LinearGradient drawerTopBg(BuildContext c) =>
      _dark(c)
          ? const LinearGradient(
            colors: [
              Color.fromARGB(255, 4, 9, 32),
              Color.fromARGB(255, 59, 21, 21),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
          : const LinearGradient(
            colors: [
              Color.fromARGB(255, 243, 199, 199),
              Color.fromARGB(255, 197, 215, 241),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

  /* general foreground */
  static Color onBg(BuildContext c) => _dark(c) ? Colors.white : Colors.black;

  /* glass fill */
  static Color glassFill(BuildContext c) =>
      _dark(c) ? Colors.white.withOpacity(.07) : Colors.black.withOpacity(.07);

  /* accents */
  static Color accent(BuildContext c) => _dark(c) ? _pinkD : _pinkL;
  static Color danger(BuildContext c) => _dark(c) ? _orangeD : _orangeL;
  static Color blue(BuildContext c) => _dark(c) ? _blueD : _blueL;
}

const double _kGlassBlur = 16;

/*──────────────────────── HomeScreen ─────────────────────────*/
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /* state */
  bool _showGoogleSheet = false;
  bool _isDefault = false;
  bool _loading = true;
  List<MessageRow> _rows = [];
  String _statusKey = 'status_none';
  List<String> _statusArgs = [];
  Map<String, String> _statusNamed = const {};
  bool _sending = false;

  final SmsService _sms = SmsService();
  static const platform = MethodChannel('sms_handler');
  void _setStatus(
    String k, {
    List<String> args = const [],
    Map<String, String> named = const {},
  }) {
    setState(() {
      _statusKey = k;
      _statusArgs = args;
      _statusNamed = named;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadImportPreference();
    _check(); // <-- add this
  }

  Future<bool> requestSmsPermissions() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
      if (!status.isGranted) return false;
    }
    return true;
  }

  Future<bool> checkDefaultSmsApp() async {
    try {
      final bool isDefault = await platform.invokeMethod('isDefaultSmsApp');
      return isDefault;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> promptForDefaultSmsApp() async {
    print("Prompting for default SMS app..."); // Debug print
    try {
      await platform.invokeMethod('promptDefaultSmsApp');
    } on PlatformException catch (e) {
      print("PlatformException: $e");
    }
  }

  Future<void> _loadImportPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showGoogleSheet = prefs.getBool('showGoogleSheet') ?? false;
    });
  }

  Future<void> _saveImportPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showGoogleSheet', value);
    setState(() {
      _showGoogleSheet = value;
    });
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final isDefault = await checkDefaultSmsApp();
    setState(() {
      _isDefault = isDefault;
      _loading = false;
    });
  }

  /*──────────────────────── build ─────────────────────────*/
  @override
  Widget build(BuildContext context) {
    final lic = context.watch<LicenseManager>();
    return Stack(
      children: [
        Container(color: _P.bg(context)),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: _glassAppBar(context),
          drawer: _drawer(context, lic),
          body: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight + 24),
            child: Column(
              children: [
                _buttons(context, lic),
                _statusBar(context),
                Expanded(child: MessageTable(rows: _rows)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /*──────────────────────── AppBar ─────────────────────────*/
  PreferredSizeWidget _glassAppBar(BuildContext c) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Image.asset('assets/logo/logo.png', height: 10),
        ),
      ),
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
          child: Container(decoration: BoxDecoration(color: _P.glassFill(c))),
        ),
      ),
      actions: [
        // messsage icon
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: IconButton(
            icon: const Icon(Icons.sms),
            iconSize: 28,
            onPressed: () async {
              final hasPermission = await requestSmsPermissions();
              if (!hasPermission) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('sms_permission_denied'.tr())),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => ChangeNotifierProvider(
                        create:
                            (_) => SmsProvider(SmscService(), SmsRepository()),
                        child: SmsScreen(),
                      ),
                ),
              );
            },
            color: _P.onBg(c),
          ),
        ),
        // if on paid display diamond icon
        if (context.read<LicenseManager>().edition == Edition.paid)
          IconButton(
            icon: const Icon(Icons.diamond),
            onPressed: () {},
            color: _P.accent(c),
          ),
      ],
    );
  }

  // Function to launch the user manual URL
  void _launchManual() async {
    final url = Uri.parse(
      'https://docs.google.com/document/d/1DQjZP9R72GfB7sZGacOfAZ9-sEft3-X3Dmcknl0t8fE/edit?tab=t.0',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  /*──────────────────────── Drawer (monochrome) ─────────────────────────*/
  Drawer _drawer(BuildContext ctx, LicenseManager lic) {
    final fg = _P.onBg(ctx);
    return Drawer(
      backgroundColor: _P.drawerBg(ctx),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(gradient: _P().drawerTopBg(context)),
            child: Center(
              child: Image.asset('assets/logo/logo.png', height: 64),
            ),
          ),
          SwitchListTile(
            title: Text(
              _showGoogleSheet
                  ? 'use_google_sheet'.tr()
                  : 'use_excel_file'.tr(),
              style: TextStyle(color: fg),
            ),
            secondary: Icon(Icons.swap_horiz, color: fg),
            value: _showGoogleSheet,
            onChanged: (value) => _saveImportPreference(value),
          ),

          ListTile(
            leading: Icon(Icons.language, color: fg),
            title: Text('language'.tr(), style: TextStyle(color: fg)),
            trailing: _languageMenu(ctx),
          ),
          // Usage in your widget tree
          InkWell(
            onTap: _launchManual,
            child: ListTile(
              leading: Icon(Icons.help_outline, color: fg),
              title: Text('user_manual'.tr(), style: TextStyle(color: fg)),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              lic.edition == Edition.free
                  ? Icons.workspace_premium_outlined
                  : Icons.diamond,
              color: lic.edition == Edition.free ? fg : _P.accent(ctx),
            ),
            title: Text(
              lic.edition == Edition.free ? 'upgrade'.tr() : 'premium'.tr(),
              style: TextStyle(color: fg),
            ),
            // inside the Drawer ListTile that shows “Upgrade / Premium”
            onTap: () async {
              Navigator.pop(ctx);
              if (lic.edition == Edition.free) {
                final purchase = Provider.of<PurchaseService>(
                  ctx,
                  listen: false,
                );
                if (!purchase.ready) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Store not available')),
                  );
                  return;
                }
                await purchase.buy(); // triggers in-app-purchase flow
              }
            },
          ),
          // ListTile(
          //   leading: Icon(Icons.sms, color: fg),
          //   title: Text('SMS Features', style: TextStyle(color: fg)),
          //   onTap: () {
          //     Navigator.pop(ctx);
          //     Navigator.of(context).push(
          //       MaterialPageRoute(
          //         builder:
          //             (_) => ChangeNotifierProvider(
          //               create:
          //                   (_) => SmsProvider(
          //                     SmscService(),
          //                     SmsRepository(), // No parameters needed now
          //                   ),
          //               child: SmsScreen(),
          //             ),
          //       ),
          //     );
          //   },
          // ),
          // SwitchListTile(
          //   title: Text('Activate as Default SMS App'),
          //   subtitle:
          //       _isDefault
          //           ? Text('This app is your default SMS handler')
          //           : Text('Not the default SMS app'),
          //   value: _isDefault,
          //   onChanged:
          //       _loading
          //           ? null
          //           : (val) async {
          //             if (val && !_isDefault) {
          //               // only allow switching ON
          //               await promptForDefaultSmsApp();
          //               await Future.delayed(Duration(seconds: 1));
          //               await _check();
          //             }
          //           },

          //   secondary: Icon(Icons.sms),
          // ),
        ],
      ),
    );
  }

  /*──────────────────────── language popup ─────────────────────────*/
  PopupMenuButton<Locale> _languageMenu(BuildContext c) =>
      PopupMenuButton<Locale>(
        icon: Icon(Icons.arrow_drop_down, color: _P.onBg(c)),
        itemBuilder:
            (_) =>
                context.supportedLocales.map((loc) {
                  // lang code is 'en' or 'sw' or 'fr' or 'de' or sp

                  final name =
                      loc.languageCode == 'sw'
                          ? 'Kiswahili'
                          : loc.languageCode == 'fr'
                          ? 'Français'
                          : loc.languageCode == 'de'
                          ? 'Deutsch'
                          : loc.languageCode == 'ar'
                          ? 'العربية'
                          // : loc.languageCode == 'sp'
                          // ? 'Español'
                          : 'English';
                  return PopupMenuItem(value: loc, child: Text(name));
                }).toList(),
        onSelected: (loc) => context.setLocale(loc),
      );

  /*──────────────────────── button row ─────────────────────────*/
  Widget _buttons(BuildContext ctx, LicenseManager lic) {
    final canSend = !_sending && _rows.isNotEmpty && !lic.isExpired;
    // if expired, disable the send button
    return Column(
      children: [
        // text field for direction of use: This app receives an excel file &amp; sends texts.
        // The excel should have tel number &amp; message columns.
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'app_desc'.tr(),
              style: TextStyle(
                color: _P.onBg(ctx),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          child: Row(
            // space between buttons
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_showGoogleSheet)
                ElevatedButton.icon(
                  style: _btnStyle(ctx),
                  onPressed: _sending ? null : _importFile,
                  icon: const Icon(Icons.file_open),
                  label: Text('import_btn'.tr()),
                ),
              if (_showGoogleSheet)
                ElevatedButton.icon(
                  style: _btnStyle(ctx),
                  onPressed:
                      _sending
                          ? null
                          : () {
                            importFromGoogleSheet(
                              context: context,
                              onStatus: _setStatus,
                              onImport: (rows) {
                                setState(() => _rows = rows);
                                _setStatus(
                                  'status_rows',
                                  args: ['${rows.length}'],
                                );
                              },
                            );
                          },
                  icon: const Icon(Icons.cloud_download),
                  label: Text('import_google_sheet'.tr()),
                ),

              const SizedBox(width: 4), // space between buttons
              // if expired, show dialog after clicking send button
              if (lic.isExpired)
                ElevatedButton.icon(
                  style: _btnStyle(ctx, danger: true),
                  onPressed: () {
                    _setStatus('status_trial');
                    showDialog(
                      context: ctx,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text("trial_expired".tr()),
                          content: Text("cannot_send_msg".tr()),
                          actions: [
                            // upgrade button
                            TextButton(
                              child: Text("upgrade_btn".tr()),
                              onPressed: () async {
                                Navigator.of(context).pop(); // Close the dialog
                                final purchase =
                                    context.read<PurchaseService>();
                                if (!purchase.ready) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Store_not_available'.tr()),
                                    ),
                                  );
                                  return;
                                }
                                await purchase
                                    .buy(); // triggers in-app-purchase flow
                              },
                            ),
                            TextButton(
                              child: Text("close_btn".tr()),
                              onPressed: () {
                                Navigator.of(context).pop(); // Close the dialog
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: Text('send_btn'.tr()),
                )
              else if (!_sending)
                ElevatedButton.icon(
                  style: _btnStyle(ctx),
                  onPressed: canSend ? _sendAll : null,
                  icon: const Icon(Icons.send),
                  label: Text(
                    'send_btn'.tr(namedArgs: {'max': '${lic.maxPerSession}'}),
                  ),
                )
              else
                ElevatedButton.icon(
                  style: _btnStyle(ctx, danger: true),
                  onPressed: () {
                    _setStatus('status_cancelling');
                    _sms.cancel();
                  },
                  icon: const Icon(Icons.cancel),
                  label: Text('cancel_btn'.tr()),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /*──────────────────────── status bar ─────────────────────────*/
  Widget _statusBar(BuildContext c) => Padding(
    // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    // child: _glass(
    //   c,
    padding: const EdgeInsets.all(8),
    child: Text(
      _statusKey.tr(args: _statusArgs, namedArgs: _statusNamed),
      style: TextStyle(fontWeight: FontWeight.bold, color: _P.onBg(c)),
    ),
    // ),
  );

  /*──────────────── CSV import helpers – unchanged ───────────────*/
  Future<void> _importFile() async {
    final initDir = await FolderMemory.getPath();

    // 1.  Let the user *only* pick the formats you actually support
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xls', 'xlsx', 'xlsm'],
      initialDirectory: initDir,
    );
    if (res == null || res.files.single.path == null) return; // user cancelled

    final path = res.files.single.path!;
    await FolderMemory.setPath(File(path).parent.path);

    _setStatus('status_loading'); // show spinner
    try {
      // 2.  Try to load the file
      final rows = await FileLoader.load(File(path));

      // 3.  Continue with your normal flow
      // final ccInFile = _detectExcelCc(rows);
      // final savedCc = await CountryCodeManager.getCode();
      // if (ccInFile != null && (savedCc == null || savedCc != ccInFile)) {
      //   final useExcel = await _askExcelCcDecision(context, ccInFile);
      //   if (useExcel == true) await CountryCodeManager.setCode(ccInFile);
      // }

      setState(() => _rows = rows);
      _setStatus('status_rows', args: ['${rows.length}']);
    } on UnsupportedError catch (e) {
      // 4.  FileLoader rejected the type → stop spinner & notify user
      _setStatus('try_again'.tr());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Unknown error'),
        ), // “Unsupported file type: .docx”
      );
    } catch (e) {
      // 5.  Any other unexpected failure
      _setStatus('unexpected_failure');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t import that file')),
      );
    }
  }

  /*──────────────── send-all – unchanged except palette refs ───────*/
  Future<void> _sendAll() async {
    final lic = context.read<LicenseManager>();
    if (lic.isExpired) {
      _setStatus('status_trial');
      return;
    }

    String? cc = await CountryCodeManager.getCode();
    if (cc == null) {}

    setState(() => _sending = true);
    _setStatus('status_send');

    await _sms.sendAll(
      _rows,
      countryCode: cc,
      maxPerSession: lic.maxPerSession,
      onStatus: (s) => _setStatus('status_progress', args: [s]),
      onRowUpdate: () => setState(() {}),
      onDone: (sent, skipped, {bool cancelled = false}) {
        setState(() => _sending = false);
        _setStatus(
          cancelled ? 'status_cancel' : 'status_done',
          named: {'sent': '$sent', 'skipped': '$skipped'},
        );

        // 🔔 NEW — local notification
        if (!cancelled) {
          Notifier.instance.show(
            'sms_finished'.tr(),
            'sms_summary'.tr(
              namedArgs: {'sent': '$sent', 'skipped': '$skipped'},
            ),
          );
        }
      },
    );
  }

  // /*──────────────── ask / edit CC dialog – unchanged ──────────────*/
  // Future<String?> _askCountryCode(BuildContext ctx, {String? initial}) async {
  //   final ctrl = TextEditingController(text: initial?.replaceAll('+', ''));
  //   return showDialog<String>(
  //     context: ctx,
  //     builder:
  //         (_) => AlertDialog(
  //           title: Text(
  //             initial == null ? 'Enter country code' : 'change_cc'.tr(),
  //           ),
  //           content: TextField(
  //             controller: ctrl,
  //             keyboardType: TextInputType.phone,
  //             decoration: InputDecoration(
  //               prefixText: '+',
  //               hintText: '1',
  //               focusedBorder: UnderlineInputBorder(
  //                 borderSide: BorderSide(color: _P.blue(ctx)),
  //               ),
  //             ),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(ctx),
  //               child: Text('Cancel', style: TextStyle(color: _P.blue(ctx))),
  //             ),
  //             ElevatedButton(
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: _P.danger(ctx),
  //               ),
  //               onPressed:
  //                   () => Navigator.pop(
  //                     ctx,
  //                     ctrl.text.trim().replaceAll('+', ''),
  //                   ),
  //               child: const Text('Save'),
  //             ),
  //           ],
  //         ),
  //   );
  // }

  /*──────────────── glass container & button style ───────────────*/
  Widget _glass(
    BuildContext c, {
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(color: _P.glassFill(c)),
          child: child,
        ),
      ),
    );
  }

  ButtonStyle _btnStyle(BuildContext c, {bool danger = false}) {
    final bg =
        danger ? _P.danger(c).withOpacity(.25) : _P.accent(c).withOpacity(.25);
    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: _P.onBg(c),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}
