// lib/widgets/message_table.dart
import 'dart:math';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gately/models/message_row.dart';

/*──────────────────────── palette helper ───────────────────────*/
class _C {
  static Brightness _b(BuildContext c) => Theme.of(c).brightness;
  static bool _dark(BuildContext c) => _b(c) == Brightness.dark;

  /* brand-ish accents – tweak if you like */
  static const _blueL = Color(0xFF02A3E8);
  static const _blueD = Color(0xFF339DC0);
  static const _redL = Color(0xFFED1D25);
  static const _redD = Color(0xFFB83239);

  /* derived colours */
  static Color blue(BuildContext c) => _dark(c) ? _blueD : _blueL;
  static Color red(BuildContext c) => _dark(c) ? _redD : _redL;
  static Color fg(BuildContext c) => _dark(c) ? Colors.white : Colors.black;
  static Color rowBg(BuildContext c) =>
      _dark(c) ? Colors.white.withOpacity(.03) : Colors.black.withOpacity(.03);
  static Color glassFill(BuildContext c) =>
      _dark(c) ? Colors.white.withOpacity(.07) : Colors.black.withOpacity(.07);
  static Color glassBorder(BuildContext c) =>
      _dark(c) ? Colors.white.withOpacity(.25) : Colors.black.withOpacity(.15);
}

const double _kGlassBlur = 16;
const double _kMobileBP = 600;
const double _kTabletBP = 1024;

/*──────────────────────── widget ───────────────────────────────*/
class MessageTable extends StatefulWidget {
  const MessageTable({super.key, required this.rows});
  final List<MessageRow> rows;

  @override
  State<MessageTable> createState() => _MessageTableState();
}

class _MessageTableState extends State<MessageTable> {
  static const int _pageSize = 100;
  int _page = 0;

  /*───────────────────────────────────────────────────────────────*/
  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();

    final pageCount = (widget.rows.length / _pageSize).ceil();
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, widget.rows.length);

    final w = MediaQuery.of(context).size.width;
    final mobile = w < _kMobileBP;
    final tablet = w >= _kMobileBP && w < _kTabletBP;
    final colGap =
        mobile
            ? 8.0
            : tablet
            ? 12.0
            : 24.0;

    return Column(
      children: [
        /*──────── table in glass ────────*/
        Expanded(
          child: Scrollbar(
            thumbVisibility: !mobile,
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _glass(
                  context,
                  // padding: const EdgeInsets.all(8),
                  child: DataTable(
                    columnSpacing: colGap,
                    headingRowHeight: mobile ? 44 : 56,
                    dataRowHeight: mobile ? 44 : null,
                    dividerThickness: .4,
                    headingRowColor: WidgetStateProperty.all(_C.rowBg(context)),
                    dataRowColor: WidgetStateProperty.all(_C.rowBg(context)),
                    columns: [
                      DataColumn(
                        label: _header('table_number'.tr(), mobile, context),
                      ),
                      DataColumn(
                        label: _header('table_send_to'.tr(), mobile, context),
                      ),
                      DataColumn(
                        label: _header(
                          'table_text_to_send'.tr(),
                          mobile,
                          context,
                        ),
                        columnWidth: const FixedColumnWidth(150),
                      ),
                      DataColumn(
                        label: _header('table_status'.tr(), mobile, context),
                        columnWidth: const FixedColumnWidth(80),
                      ),
                    ],
                    rows: [
                      for (int i = start; i < end; i++)
                        _row(context, i, widget.rows[i], mobile),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        /*──────── pager glass ───────────*/
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: _glass(
            context,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _pager(context, pageCount, mobile),
          ),
        ),
      ],
    );
  }

  /*────────────────── helpers ─────────────────*/
  Text _header(String s, bool mobile, BuildContext c) => Text(
    s,
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: _C.blue(c),
      fontSize: mobile ? 12 : 14,
    ),
  );

  DataRow _row(BuildContext c, int idx, MessageRow r, bool mobile) => DataRow(
    cells: [
      _cell(
        c,
        r,
        SizedBox(
          width: mobile ? 40 : 60,
          child: _text('${idx + 1}', mobile, c, center: true),
        ),
      ),
      _cell(
        c,
        r,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: mobile ? 120 : 160),
          child: _text(_cut(r.numbers.join(';'), mobile ? 12 : 20), mobile, c),
        ),
      ),
      _cell(
        c,
        r,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: mobile ? 300 : 600),
          child: _text(_cut(r.body, mobile ? 40 : 120), mobile, c),
        ),
      ),
      _cell(
        c,
        r,
        SizedBox(width: mobile ? 60 : 80, child: _text(r.status, mobile, c)),
      ),
    ],
  );

  Text _text(String s, bool mobile, BuildContext c, {bool center = false}) =>
      Text(
        s,
        textAlign: center ? TextAlign.center : null,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _C.fg(c), fontSize: mobile ? 12 : 14),
      );

  DataCell _cell(BuildContext c, MessageRow r, Widget w) =>
      DataCell(w, onTap: () => _dialog(c, r));

  /*──────── pager • dots / slider ───────*/
  Widget _pager(BuildContext c, int pc, bool mobile) {
    final iconClr = _C.fg(c).withOpacity(.9);
    final left = Icon(Icons.chevron_left, color: iconClr);
    final right = Icon(Icons.chevron_right, color: iconClr);

    if (pc > 30) {
      return Row(
        children: [
          IconButton(
            icon: left,
            onPressed: _page > 0 ? () => setState(() => _page--) : null,
          ),
          Expanded(
            child: Slider(
              min: 0,
              max: (pc - 1).toDouble(),
              divisions: pc - 1,
              value: _page.toDouble(),
              label: '${_page + 1}',
              activeColor: _C.blue(c),
              inactiveColor: _C.fg(c).withOpacity(.3),
              onChanged: (v) => setState(() => _page = v.round()),
            ),
          ),
          IconButton(
            icon: right,
            onPressed: _page < pc - 1 ? () => setState(() => _page++) : null,
          ),
        ],
      );
    }
    if (pc == 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: left,
          onPressed: _page > 0 ? () => setState(() => _page--) : null,
        ),
        ...List.generate(
          pc,
          (p) => InkWell(
            onTap: () => setState(() => _page = p),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: mobile ? 8 : 10,
              height: mobile ? 8 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p == _page ? _C.blue(c) : _C.fg(c).withOpacity(.3),
              ),
            ),
          ),
        ),
        IconButton(
          icon: right,
          onPressed: _page < pc - 1 ? () => setState(() => _page++) : null,
        ),
      ],
    );
  }

  /*──────── modal dialog ───────*/
  void _dialog(BuildContext c, MessageRow r) {
    showDialog(
      context: c,
      barrierColor: Colors.black26,
      builder:
          (_) => LayoutBuilder(
            builder: (ctx, cons) {
              final w = min(cons.maxWidth * .9, 480.0);
              final h = min(cons.maxHeight * .8, 600.0);
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: w, maxHeight: h),
                  child: _glass(
                    ctx,
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      type: MaterialType.transparency,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _dialogHeader(ctx, 'table_send_to'.tr()),
                            const SizedBox(height: 4),
                            Text(
                              r.numbers.join(';'),
                              style: TextStyle(color: _C.fg(ctx)),
                            ),
                            const SizedBox(height: 12),
                            _dialogHeader(ctx, 'table_text_to_send'.tr()),
                            const SizedBox(height: 4),
                            Text(r.body, style: TextStyle(color: _C.fg(ctx))),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      widget.rows.remove(r);
                                      _page = _page.clamp(
                                        0,
                                        (widget.rows.length / _pageSize)
                                                .ceil() -
                                            1,
                                      );
                                    });
                                    Navigator.pop(ctx);
                                  },
                                  child: Text(
                                    'remove_row_btn'.tr(),
                                    style: TextStyle(
                                      color: _C.red(ctx),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(
                                    'close_btn'.tr(),
                                    style: TextStyle(color: _C.fg(ctx)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Text _dialogHeader(BuildContext c, String s) => Text(
    s,
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: _C.fg(c),
    ),
  );

  String _cut(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  /*──────── glass wrapper helper ───────*/
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
          decoration: BoxDecoration(color: _C.glassFill(c)),
          child: child,
        ),
      ),
    );
  }
}
