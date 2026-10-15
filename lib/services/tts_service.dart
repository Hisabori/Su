import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts tts = FlutterTts();
  Future<void> speak(String text) async {
    await tts.setLanguage('ko-KR');
    await tts.speak(text);
  }

  Future<void> stop() async {
    await tts.stop();
  }
}
