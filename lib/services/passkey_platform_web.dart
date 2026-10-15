import 'dart:convert';
import 'dart:js_interop';

@JS('suhoPasskeys.isEnrolled')
external JSBoolean _enrolled();
@JS('suhoPasskeys.read')
external JSString? _read(JSString key);
@JS('suhoPasskeys.write')
external void _write(JSString key, JSString value);
@JS('suhoPasskeys.remove')
external void _remove(JSString key);
@JS('suhoPasskeys.lock')
external void _lock();
@JS('suhoPasskeys.status')
external JSPromise<JSString> _status();
@JS('suhoPasskeys.enroll')
external JSPromise<JSString> _enroll(JSString data, JSString label);
@JS('suhoPasskeys.unlock')
external JSPromise<JSString> _unlock();
@JS('suhoPasskeys.refresh')
external JSPromise<JSString> _refresh(JSString data);
@JS('suhoPasskeys.forget')
external JSPromise<JSString> _forget();

bool get passkeyEnrolled => _enrolled().toDart;
String? passkeyRead(String key) => _read(key.toJS)?.toDart;
void passkeyWrite(String key, String value) => _write(key.toJS, value.toJS);
void passkeyRemove(String key) => _remove(key.toJS);
void passkeyLock() => _lock();
Future<Map<String, dynamic>> _result(JSPromise<JSString> promise) async =>
    Map<String, dynamic>.from(jsonDecode((await promise.toDart).toDart) as Map);
Future<Map<String, dynamic>> passkeyStatus() => _result(_status());
Future<Map<String, dynamic>> passkeyEnroll(String data, String label) =>
    _result(_enroll(data.toJS, label.toJS));
Future<Map<String, dynamic>> passkeyUnlock() => _result(_unlock());
Future<Map<String, dynamic>> passkeyRefresh(String data) =>
    _result(_refresh(data.toJS));
Future<Map<String, dynamic>> passkeyForget() => _result(_forget());
