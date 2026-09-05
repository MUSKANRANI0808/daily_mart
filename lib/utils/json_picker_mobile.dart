import 'dart:convert';
import 'package:file_picker/file_picker.dart';

Future<String?> pickJsonFileString() async {
  try {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.any,
    );
    if (files.isNotEmpty) {
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        return utf8.decode(bytes, allowMalformed: true).trim();
      }
    }
  } catch (_) {}
  return null;
}
