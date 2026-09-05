import 'dart:async';
import 'dart:html' as html;

Future<String?> pickJsonFileString() async {
  final Completer<String?> completer = Completer<String?>();
  final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
  uploadInput.accept = '.json,application/json,text/plain';
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) {
        final result = reader.result;
        if (result is String) {
          completer.complete(result);
        } else {
          completer.complete(null);
        }
      });
      reader.onError.listen((e) {
        completer.complete(null);
      });
      reader.readAsText(file);
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
