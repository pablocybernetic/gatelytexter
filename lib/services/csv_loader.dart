// lib/services/file_loader.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:gately/models/message_row.dart';
import 'package:path/path.dart' as p;

class FileLoader {
  static List<MessageRow> parseCsv(String contents) {
    final rows = const CsvToListConverter().convert(contents);
    return _parseRows(rows);
  }

  static Future<List<MessageRow>> load(File file) async {
    final ext = p.extension(file.path).toLowerCase();

    if (ext == '.csv') {
      final raw = await file.readAsString();
      final rows = const CsvToListConverter().convert(raw);
      return _parseRows(rows);
    }

    if (['.xls', '.xlsx', '.xlsm'].contains(ext)) {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) return [];

      final sheet = excel.tables.values.first;
      final rows = sheet!.rows;

      return _parseRows(rows);
    }

    throw UnsupportedError('Unsupported file type: $ext');
  }

  static List<MessageRow> _parseRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) return [];

    return rows.skip(1).map((r) {
      final phone = _getCellValue(r, 0);
      final message = _getCellValue(r, 1);
      return MessageRow(
        numbers: phone.split(';').map((s) => s.trim()).toList(),
        body: message,
      );
    }).toList();
  }

  static String _getCellValue(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    final cell = row[index];

    // Check if the cell is a Cell object (from 'excel' package)
    if (cell is Data) {
      return cell.value?.toString().trim() ?? '';
    }

    // If not, assume it's a simple string or number
    return cell?.toString().trim() ?? '';
  }
}
