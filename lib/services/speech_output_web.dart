import 'dart:js_interop';

@JS('suhoSpeech.available')
external JSBoolean get _available;
@JS('suhoSpeech.speak')
external JSPromise<JSString> _speak(JSString text, JSFunction callback);
@JS('suhoSpeech.stop')
external void _stop();

bool get webSpeechAvailable => _available.toDart;
Future<String> speakWeb(String text, void Function(bool) state) async =>
    (await _speak(text.toJS, ((JSBoolean value) => state(value.toDart)).toJS)
            .toDart)
        .toDart;
void stopWeb() => _stop();
