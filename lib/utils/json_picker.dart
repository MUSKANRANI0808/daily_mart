import 'package:daily_mart/utils/json_picker_web.dart' if (dart.library.io) 'package:daily_mart/utils/json_picker_mobile.dart';

class JsonPickerHelper {
  static Future<String?> pickJsonString() async {
    return pickJsonFileString();
  }
}
