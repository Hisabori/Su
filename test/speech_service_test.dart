import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:suho_angel/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('explicit Korean answers accept punctuation but reject mixed intent',
      () {
    expect(interpretSpokenAnswer('네, 맞아요!'), isTrue);
    expect(interpretSpokenAnswer('아니에요.'), isFalse);
    expect(interpretSpokenAnswer('네 아니요'), isNull);
    expect(interpretSpokenAnswer('잘 모르겠어요'), isNull);
    expect(interpretSpokenAnswer(''), isNull);
  });
  test(
      'final speech result survives stopped-listening status and stop blocks stale results',
      () async {
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'initialize' ||
                call.method == 'listen' ||
                call.method == 'has_permission'
            ? true
            : null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Future<void> event(String method, Object arguments) async {
      await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, arguments)),
          (_) {});
    }

    final service = SpeechService(engine: SpeechToText.withMethodChannel());
    final results = <String>[];
    await service.listen(results.add);
    await event('notifyStatus', 'notListening');
    final finalResult = jsonEncode({
      'alternates': [
        {'recognizedWords': '네', 'confidence': .9}
      ],
      'resultType': 2
    });
    await event('textRecognition', finalResult);
    await event('textRecognition', finalResult);
    expect(results, ['네']);
    await service.stop();
    await event('textRecognition', finalResult);
    expect(results, ['네']);
  });
}
