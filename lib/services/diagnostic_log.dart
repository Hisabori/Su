import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Only fixed codes are accepted: never pass server messages or record contents.
abstract final class DiagnosticLog {
  static final traceId = List.generate(16, (_) => Random.secure().nextInt(256))
      .map((n) => n.toRadixString(16).padLeft(2, '0'))
      .join();
  static const areas = {'session', 'work_history', 'device_history'};
  static const codes = {
    'read_failed',
    'save_failed',
    'backup_failed',
    'rows_recovered',
    'restore_failed',
    'login_ok',
    'restore_ok',
    'login_rejected'
  };
  static final recent = <Map<String, String>>[];
  static final _sent = <String, DateTime>{};
  static void record(String area, String code) {
    if (!areas.contains(area) || !codes.contains(code)) return;
    final now = DateTime.now();
    final key = '$area/$code';
    if (_sent[key] != null &&
        now.difference(_sent[key]!) < const Duration(minutes: 1)) {
      return;
    }
    _sent[key] = now;
    final event = {'trace': traceId, 'area': area, 'code': code};
    recent.add({...event, 'at': now.toUtc().toIso8601String()});
    if (recent.length > 50) recent.removeAt(0);
    debugPrint(jsonEncode({'event': 'suho_diagnostic', ...event}));
    if (kIsWeb &&
        Uri.base.scheme == 'https' &&
        Uri.base.host == 'suho-angel.vercel.app') {
      unawaited(_send(event));
    }
  }

  static Future<void> _send(Map<String, String> event) async {
    final client = http.Client();
    try {
      await client
          .post(Uri.parse('https://suho-angel.vercel.app/api/diagnostics'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(event))
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Diagnostics must never block login, saving or recovery.
    } finally {
      client.close();
    }
  }
}
