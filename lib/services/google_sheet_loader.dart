import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:gately/models/message_row.dart';
import 'package:gately/services/csv_loader.dart';

class GoogleSheetLoader {
  static Future<List<MessageRow>> loadFromUrl(String url) async {
    try {
      // Validate URL
      if (!url.contains('docs.google.com/spreadsheets')) {
        throw FormatException('google_sheet_url_invalid'.tr());
      }

      final csvUrl = _convertSheetUrlToCsv(url);
      final uri = Uri.tryParse(csvUrl);

      if (uri == null) {
        throw FormatException('invalid_google_sheet_url'.tr());
      }

      final httpClient = HttpClient();
      final request = await httpClient.getUrl(uri);

      final response = await request.close();

      if (response.statusCode == 401) {
        throw HttpException('google_sheet_private_error'.tr());
      }

      if (response.statusCode == 403) {
        throw HttpException('google_sheet_access_denied');
      }

      if (response.statusCode == 404) {
        throw HttpException('Google Sheet not found (404).');
      }

      if (response.statusCode != 200) {
        throw HttpException(
          'Unexpected error fetching the Google Sheet (HTTP ${response.statusCode}).',
        );
      }

      final contents = await response.transform(utf8.decoder).join();

      if (contents.trim().isEmpty) {
        throw FormatException('google_sheet_empty'.tr());
      }

      return FileLoader.parseCsv(contents);
    } on SocketException {
      throw Exception('no_internet_connection'.tr());
    } on FormatException catch (e) {
      throw Exception('URL error: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('Google Sheet error: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  static String _convertSheetUrlToCsv(String inputUrl) {
    final uri = Uri.parse(inputUrl);
    final sheetId =
        uri.pathSegments.contains('d')
            ? uri.pathSegments[uri.pathSegments.indexOf('d') + 1]
            : null;
    final gid = uri.queryParameters['gid'] ?? '0';

    if (sheetId == null || sheetId.isEmpty) {
      throw FormatException('invalid_google_sheet_url'.tr());
    }

    return 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=$gid';
  }
}
