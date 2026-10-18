import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('prefer Korean premium voice and preserve its identifier', () {
    final voice = preferredKoreanVoice([
      {'name': 'Natural English', 'locale': 'en-US', 'quality': 'premium'},
      {'name': 'Yuna', 'locale': 'ko-KR', 'quality': 'default'},
      {
        'name': 'Yuna',
        'locale': 'ko-KR',
        'quality': 'premium',
        'identifier': 'ko.premium'
      },
    ]);
    expect(voice?['identifier'], 'ko.premium');
    expect(
        preferredKoreanVoice([
          {'name': 'English', 'locale': 'en-US'}
        ]),
        isNull);
  });
  test('speech preparation preserves meaning, numbers and paragraph pauses',
      () {
    expect(prepareSpeechText('  용량은  0.5%입니다.\r\n\r\n다음 질문입니다.  '),
        '용량은 0.5%입니다.\n\n다음 질문입니다.');
  });
  test('stopping during voice discovery cannot play a stale question',
      () async {
    final calls = <MethodCall>[];
    final voices = Completer<List<Map<String, String>>>();
    final discovered = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (call) async {
      calls.add(call);
      if (call.method == 'getVoices') {
        discovered.complete();
        return voices.future;
      }
      return 1;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));
    final tts = TtsService();
    final reading = tts.speak('이전 질문입니다.');
    await discovered.future;
    await tts.stop();
    voices.complete([
      {'name': '한국어', 'locale': 'ko-KR'}
    ]);
    await reading;
    expect(calls.where((c) => c.method == 'speak'), isEmpty);
  });
}
