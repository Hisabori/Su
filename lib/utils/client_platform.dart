import 'package:flutter/foundation.dart';

String get clientPlatform => kIsWeb
    ? 'web'
    : switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => 'desktop',
      };
