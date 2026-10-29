import 'package:speech_to_text/speech_to_text.dart';

/// Only explicit short answers are accepted; ambiguous transcripts stay manual.
bool? interpretSpokenAnswer(String text) {
  final value = text.replaceAll(RegExp(r'[\s.,!?。！？]'), '').toLowerCase();
  if (const {'네', '예', '응', '다음', '맞아요', '네맞아요', '예맞아요', '그렇습니다', '네그렇습니다'}
      .contains(value)) {
    return true;
  }
  if (const {'아니요', '아니오', '아니', '아뇨', '아닙니다', '아니에요', '아니예요'}
      .contains(value)) {
    return false;
  }
  return null;
}

class SpeechService {
  final SpeechToText speech;
  SpeechService({SpeechToText? engine}) : speech = engine ?? SpeechToText();
  void Function(String)? onErrorMessage;
  bool _acceptErrors = false;
  void Function(bool)? onListeningChanged;
  int _generation = 0;
  bool _ready = false;
  String? lastError;

  Future<bool> listen(void Function(String) onResult) async {
    final request = ++_generation;
    lastError = null;
    _acceptErrors = true;
    if (!_ready) {
      _ready = await speech
          .initialize(
            onStatus: (status) =>
                onListeningChanged?.call(status == 'listening'),
            onError: (error) {
              if (!_acceptErrors) return;
              _acceptErrors = false;
              _generation++;
              lastError = error.errorMsg.contains('permission') ||
                      error.errorMsg.contains('not_allowed')
                  ? '마이크 권한을 허용한 뒤 다시 눌러주세요.'
                  : error.errorMsg.contains('no_match') ||
                          error.errorMsg.contains('speech_timeout')
                      ? '답변을 듣지 못했어요. 다시 말하거나 버튼으로 답해 주세요.'
                      : '음성 인식이 중단됐어요. 다시 누르거나 버튼으로 답해 주세요.';
              onListeningChanged?.call(false);
              onErrorMessage?.call(lastError!);
            },
          )
          .timeout(const Duration(seconds: 8));
    }
    if (!_ready || request != _generation) return false;
    if (speech.isListening) {
      _acceptErrors = false;
      await speech.cancel();
    }
    if (request != _generation) return false;
    _acceptErrors = true;
    var delivered = false;
    await speech.listen(
      listenOptions: SpeechListenOptions(
          localeId: 'ko-KR',
          partialResults: false,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 4)),
      onResult: (result) {
        // Some engines report "done" before their final transcript.
        if (request != _generation ||
            delivered ||
            !result.finalResult ||
            result.recognizedWords.trim().isEmpty) {
          return;
        }
        delivered = true;
        _acceptErrors = false;
        onResult(result.recognizedWords);
        onListeningChanged?.call(false);
      },
    );
    if (request != _generation || delivered) return false;
    onListeningChanged?.call(speech.isListening);
    return speech.isListening;
  }

  Future<void> stop() async {
    _generation++;
    _acceptErrors = false;
    await speech.cancel();
    onListeningChanged?.call(false);
  }
}
