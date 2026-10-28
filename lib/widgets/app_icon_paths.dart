// Generated from bundled Lucide SVGs; ISC license: assets/icons/lucide/LICENSE.
// Regenerate with python3 scripts/compile-icon-paths.py.
import 'package:flutter/material.dart';

enum AppIconKind {
  settings,
  collector,
  community,
  history,
  passkey,
  chart,
  compose,
  replay
}

Path appIconPath(AppIconKind kind) {
  switch (kind) {
    case AppIconKind.settings:
      return Path()
        ..moveTo(14, 17)
        ..lineTo(5, 17)
        ..moveTo(19, 7)
        ..lineTo(10, 7)
        ..addOval(Rect.fromCircle(center: const Offset(17, 17), radius: 3))
        ..addOval(Rect.fromCircle(center: const Offset(7, 7), radius: 3));
    case AppIconKind.collector:
      return Path()
        ..moveTo(7, 19)
        ..lineTo(4.815, 19)
        ..arcToPoint(const Offset(3.245, 18.119),
            radius: const Radius.elliptical(1.83, 1.83),
            rotation: 0,
            largeArc: false,
            clockwise: true)
        ..arcToPoint(const Offset(3.241, 16.335),
            radius: const Radius.elliptical(1.785, 1.785),
            rotation: 0,
            largeArc: false,
            clockwise: true)
        ..lineTo(7.196, 9.5)
        ..moveTo(11, 19)
        ..lineTo(19.203, 19)
        ..arcToPoint(const Offset(20.759, 18.11),
            radius: const Radius.elliptical(1.83, 1.83),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..arcToPoint(const Offset(20.759, 16.335),
            radius: const Radius.elliptical(1.784, 1.784),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(19.533, 14.215)
        ..moveTo(14, 16)
        ..lineTo(11, 19)
        ..lineTo(14, 22)
        ..moveTo(8.293, 13.596)
        ..lineTo(7.196, 9.5)
        ..lineTo(3.1, 10.598)
        ..moveTo(9.344, 5.811)
        ..lineTo(10.437, 3.919)
        ..arcToPoint(const Offset(11.985, 3),
            radius: const Radius.elliptical(1.83, 1.83),
            rotation: 0,
            largeArc: false,
            clockwise: true)
        ..arcToPoint(const Offset(13.531, 3.888),
            radius: const Radius.elliptical(1.784, 1.784),
            rotation: 0,
            largeArc: false,
            clockwise: true)
        ..lineTo(17.474, 10.731)
        ..moveTo(13.378, 9.633)
        ..lineTo(17.474, 10.731)
        ..lineTo(18.571, 6.635);
    case AppIconKind.community:
      return Path()
        ..moveTo(2.992, 16.342)
        ..arcToPoint(const Offset(3.086, 17.509),
            radius: const Radius.elliptical(2, 2),
            rotation: 0,
            largeArc: false,
            clockwise: true)
        ..lineTo(2.021, 20.799)
        ..arcToPoint(const Offset(3.257, 21.967),
            radius: const Radius.elliptical(1, 1),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(6.67, 20.969)
        ..arcToPoint(const Offset(7.769, 21.061),
            radius: const Radius.elliptical(2, 2),
            rotation: 0,
            largeArc: false,
            clockwise: true)
        ..arcToPoint(const Offset(2.992, 16.342),
            radius: const Radius.elliptical(10, 10),
            rotation: 0,
            largeArc: true,
            clockwise: false);
    case AppIconKind.history:
      return Path()
        ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 10))
        ..moveTo(12, 6)
        ..lineTo(12, 12)
        ..lineTo(16, 12);
    case AppIconKind.passkey:
      return Path()
        ..moveTo(2.586, 17.414)
        ..arcToPoint(const Offset(2, 18.828),
            radius: const Radius.elliptical(2, 2),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(2, 21)
        ..arcToPoint(const Offset(3, 22),
            radius: const Radius.elliptical(1, 1),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(6, 22)
        ..arcToPoint(const Offset(7, 21),
            radius: const Radius.elliptical(1, 1),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(7, 20)
        ..arcToPoint(const Offset(8, 19),
            radius: const Radius.elliptical(1, 1),
            rotation: 0,
            largeArc: false,
            clockwise: true)
        ..lineTo(9, 19)
        ..arcToPoint(const Offset(10, 18),
            radius: const Radius.elliptical(1, 1),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(10, 17)
        ..arcToPoint(const Offset(11, 16),
            radius: const Radius.elliptical(1, 1),
            rotation: 0,
            largeArc: false,
            clockwise: true)
        ..lineTo(11.172, 16)
        ..arcToPoint(const Offset(12.586, 15.414),
            radius: const Radius.elliptical(2, 2),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(13.4, 14.6)
        ..arcToPoint(const Offset(9.4, 10.6),
            radius: const Radius.elliptical(6.5, 6.5),
            rotation: 0,
            largeArc: true,
            clockwise: false)
        ..close()
        ..addOval(Rect.fromCircle(center: const Offset(16.5, 7.5), radius: .5));
    case AppIconKind.chart:
      return Path()
        ..moveTo(12, 16)
        ..lineTo(12, 21)
        ..moveTo(16, 14.639)
        ..lineTo(16, 21)
        ..moveTo(20, 10.656)
        ..lineTo(20, 21)
        ..moveTo(22, 3)
        ..lineTo(13.354, 11.646)
        ..arcToPoint(const Offset(12.646, 11.646),
            radius: const Radius.elliptical(0.5, 0.5),
            rotation: 0,
            largeArc: false,
            clockwise: true)
        ..lineTo(9.354, 8.354)
        ..arcToPoint(const Offset(8.647, 8.354),
            radius: const Radius.elliptical(0.5, 0.5),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(2, 15)
        ..moveTo(4, 18.463)
        ..lineTo(4, 21)
        ..moveTo(8, 14.656)
        ..lineTo(8, 21);
    case AppIconKind.compose:
      return Path()
        ..moveTo(13, 21)
        ..lineTo(21, 21)
        ..moveTo(15, 5)
        ..lineTo(19, 9)
        ..moveTo(21.174, 6.812)
        ..arcToPoint(const Offset(17.188, 2.825),
            radius: const Radius.elliptical(1, 1),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(3.842, 16.174)
        ..arcToPoint(const Offset(3.342, 17.004),
            radius: const Radius.elliptical(2, 2),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(2.021, 21.356)
        ..arcToPoint(const Offset(2.644, 21.978),
            radius: const Radius.elliptical(0.5, 0.5),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(6.997, 20.658)
        ..arcToPoint(const Offset(7.827, 20.161),
            radius: const Radius.elliptical(2, 2),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..close();
    case AppIconKind.replay:
      return Path()
        ..moveTo(3, 12)
        ..arcToPoint(const Offset(12, 3),
            radius: const Radius.elliptical(9, 9),
            rotation: 0,
            largeArc: true,
            clockwise: false)
        ..arcToPoint(const Offset(5.26, 5.74),
            radius: const Radius.elliptical(9.75, 9.75),
            rotation: 0,
            largeArc: false,
            clockwise: false)
        ..lineTo(3, 8)
        ..moveTo(3, 3)
        ..lineTo(3, 8)
        ..lineTo(8, 8);
  }
}
