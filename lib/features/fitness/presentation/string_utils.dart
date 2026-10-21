import 'dart:convert';
import 'dart:typed_data';

class StringUtils {
  static String decodeBytes(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }
}
