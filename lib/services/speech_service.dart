import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText speech = SpeechToText();
  Future<bool> listen(void Function(String) onResult) async {
    if (!await speech.initialize()) return false;
    await speech.listen(
      listenOptions: SpeechListenOptions(localeId: 'ko_KR'),
      onResult: (r) => onResult(r.recognizedWords),
    );
    return true;
  }

  Future<void> stop() => speech.stop();
}
