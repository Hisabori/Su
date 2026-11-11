import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/services/diagnostic_log.dart';

void main() {
  test('diagnostic sink failures cannot escape into login or saving', () {
    final previous = debugPrint;
    try {
      debugPrint = (String? message, {int? wrapWidth}) =>
          throw StateError('sink unavailable');
      expect(() => DiagnosticLog.record('device_history', 'save_failed'),
          returnsNormally);
      expect(DiagnosticLog.traceId, matches(RegExp(r'^[a-f0-9]{32}$')));
      final count = DiagnosticLog.recent.length;
      DiagnosticLog.record('password', 'secret');
      expect(DiagnosticLog.recent.length, count);
      expect(DiagnosticLog.recent.last.keys,
          unorderedEquals(['trace', 'area', 'code', 'at', 'error_id']));
    } finally {
      debugPrint = previous;
    }
  });
}
