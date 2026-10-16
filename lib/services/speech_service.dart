import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText speech = SpeechToText();
  void Function(bool)? onListeningChanged;
  Future<bool> listen(void Function(String) onResult) async {
    if (!await speech.initialize(
        onStatus: (status) => onListeningChanged?.call(status == 'listening'),
        onError: (_) => onListeningChanged?.call(false))) {
      return false;
    }
    await speech.listen(
      listenOptions: SpeechListenOptions(localeId: 'ko-KR'),
      onResult: (r) {
        if (r.finalResult) onResult(r.recognizedWords);
      },
    );
    onListeningChanged?.call(speech.isListening);
    return speech.isListening;
  }

  Future<void> stop() => speech.stop();
}
