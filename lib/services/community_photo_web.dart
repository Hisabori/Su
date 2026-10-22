import 'dart:convert';
import 'dart:js_interop';

@JS('suhoCommunityPhoto.pick')
external JSPromise<JSString> _pick();
bool get communityPhotoAvailable => true;
Future<Map<String, dynamic>?> pickCommunityPhoto() async {
  final text = (await _pick().toDart).toDart;
  return text.isEmpty
      ? null
      : Map<String, dynamic>.from(jsonDecode(text) as Map);
}
