import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'speech_output_platform.dart' as web;

class TtsFailure implements Exception {
  final String message;
  const TtsFailure(this.message);
}

String prepareSpeechText(String text) => text
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .replaceAll(RegExp(r' *\r?\n *'), '\n')
    .trim();

Map<String, String>? preferredKoreanVoice(List<dynamic> voices) {
  final korean = voices
      .whereType<Map>()
      .where((v) =>
          v['name'] is String &&
          v['locale'] is String &&
          RegExp(r'^ko(?:[-_]|$)', caseSensitive: false)
              .hasMatch(v['locale'] as String))
      .toList();
  int score(Map voice) {
    final quality = '${voice['quality'] ?? ''} ${voice['name']}'.toLowerCase();
    return (quality.contains('premium') ? 100 : 0) +
        (RegExp(r'enhanced|natural|neural|고품질').hasMatch(quality) ? 70 : 0) +
        (RegExp(r'google|microsoft').hasMatch(quality) ? 20 : 0);
  }

  korean.sort((a, b) => score(b).compareTo(score(a)));
  if (korean.isEmpty) return null;
  final voice = korean.first;
  return {
    for (final key in ['name', 'locale', 'identifier'])
      if (voice[key] is String) key: voice[key] as String
  };
}

class TtsService {
  final FlutterTts tts;
  int _generation = 0;
  double speed = 1.0;
  void Function(bool)? onSpeakingChanged;
  TtsService({FlutterTts? engine}) : tts = engine ?? FlutterTts() {
    if (!kIsWeb) {
      tts.setStartHandler(() => onSpeakingChanged?.call(true));
      tts.setCompletionHandler(() => onSpeakingChanged?.call(false));
      tts.setCancelHandler(() => onSpeakingChanged?.call(false));
      tts.setErrorHandler((_) => onSpeakingChanged?.call(false));
    }
  }
  Future<void> speak(String text) async {
    final content = prepareSpeechText(text);
    if (content.isEmpty) return;
    if (kIsWeb) {
      if (!web.webSpeechAvailable) {
        throw const TtsFailure('이 브라우저에서는 음성 읽기를 지원하지 않습니다. 화면의 질문을 확인해 주세요.');
      }
      final result = jsonDecode(await web.speakWeb(
          content,
          (value) => onSpeakingChanged?.call(value),
          speed.clamp(.85, 1.1))) as Map;
      if (result['ok'] != true) {
        throw TtsFailure(result['code'] == 'not-allowed'
            ? '자동 읽기가 차단됐습니다. ‘다시 듣기’를 눌러주세요.'
            : '음성을 읽지 못했습니다. ‘다시 듣기’를 눌러주세요.');
      }
      return;
    }
    final generation = ++_generation;
    await tts.stop();
    if (generation != _generation) return;
    await tts.setLanguage('ko-KR');
    if (generation != _generation) return;
    try {
      final voices = await tts.getVoices.timeout(const Duration(seconds: 2));
      if (generation != _generation) return;
      final voice = voices is List ? preferredKoreanVoice(voices) : null;
      if (voice != null) await tts.setVoice(voice);
    } catch (_) {/* Default Korean voice remains usable. */}
    if (generation != _generation) return;
    await tts.setSpeechRate((0.48 * speed).clamp(.3, .65));
    if (generation != _generation) return;
    await tts.setPitch(1.0);
    if (generation != _generation) return;
    await tts.setVolume(1.0);
    if (generation != _generation) return;
    await tts.speak(content.replaceAll(RegExp(r'\n+'), ' '));
  }

  Future<void> stop() async {
    _generation++;
    if (kIsWeb) {
      web.stopWeb();
    } else {
      await tts.stop();
    }
    onSpeakingChanged?.call(false);
  }
}
