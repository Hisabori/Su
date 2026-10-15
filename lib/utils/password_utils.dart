import 'dart:convert';

import 'package:crypto/crypto.dart';

String encodePassword(String password, String encoding) {
  switch (encoding) {
    case 'plain':
      return password;
    case 'sha256':
      return sha256.convert(utf8.encode(password)).toString();
    default:
      throw StateError('PASSWORD_ENCODING must match the server.');
  }
}
