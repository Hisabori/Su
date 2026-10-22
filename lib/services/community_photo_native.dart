import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool get communityPhotoAvailable => defaultTargetPlatform == TargetPlatform.iOS;
Future<Map<String, dynamic>?> pickCommunityPhoto() async {
  final text = await const MethodChannel('suho/community_photo')
      .invokeMethod<String>('pick');
  return text == null || text.isEmpty
      ? null
      : Map<String, dynamic>.from(jsonDecode(text) as Map);
}
