import 'dart:js_interop';

@JS('suhoBeforeUpdate')
external set _beforeUpdate(JSFunction? callback);
void registerUpdateCheckpoint(Future<void> Function()? callback) {
  _beforeUpdate = callback == null
      ? null
      : (() => callback().then((_) => true.toJS).toJS).toJS;
}
