import 'dart:convert';
import 'dart:io';
import 'package:gately/models/message_row.dart';
import 'package:gately/services/csv_loader.dart';

class GoogleSheetLoader {
  static Future<List<MessageRow>> loadFromUrl(String url) async {
    final csvUrl = _convertSheetUrlToCsv(url);
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse(csvUrl));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch Google Sheet.');
    }

    final contents = await response.transform(utf8.decoder).join();
    return FileLoader.parseCsv(contents); // ✅ use it here
  }

  static String _convertSheetUrlToCsv(String inputUrl) {
    final uri = Uri.parse(inputUrl);
    final sheetId =
        uri.pathSegments.contains('d')
            ? uri.pathSegments[uri.pathSegments.indexOf('d') + 1]
            : null;
    final gid = uri.queryParameters['gid'] ?? '0';

    if (sheetId == null) {
      throw Exception('Invalid Google Sheets URL');
    }

    return 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=$gid';
  }
}
