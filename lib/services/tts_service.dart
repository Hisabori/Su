import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts tts = FlutterTts();
  void Function(bool)? onSpeakingChanged;
  TtsService() {
    tts.setStartHandler(() => onSpeakingChanged?.call(true));
    tts.setCompletionHandler(() => onSpeakingChanged?.call(false));
    tts.setCancelHandler(() => onSpeakingChanged?.call(false));
    tts.setErrorHandler((_) => onSpeakingChanged?.call(false));
  }
  Future<void> speak(String text) async {
    await tts.setLanguage('ko-KR');
    await tts.speak(text);
  }

  Future<void> stop() async {
    await tts.stop();
    onSpeakingChanged?.call(false);
  }
}
