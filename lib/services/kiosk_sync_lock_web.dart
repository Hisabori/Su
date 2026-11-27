import 'dart:js_interop';

@JS('navigator.locks')
external _LockManager? get _locks;

extension type _LockManager(JSObject _) implements JSObject {
  external JSPromise<JSAny?> request(JSString name, JSFunction callback);
}

Future<String?> withKioskSyncLock(
    int userId, Future<String?> Function() action) async {
  final locks = _locks;
  if (locks == null) return '이 브라우저는 창 간 잠금을 지원하지 않아 관리자 갱신을 중단했습니다.';
  final value = await locks
      .request('suho-kiosk-result-$userId'.toJS,
          (() => action().then<JSAny?>((value) => value?.toJS).toJS).toJS)
      .toDart;
  return (value as JSString?)?.toDart;
}
