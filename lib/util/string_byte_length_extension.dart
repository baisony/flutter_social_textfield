// string_byte_length_extension.dart
import 'dart:convert';

extension StringByteLength on String {
  int get byteLength => utf8.encode(this).length;

  int byteLengthUntil(int charIndex) {
    return utf8.encode(this.substring(0, charIndex)).length;
  }
}
