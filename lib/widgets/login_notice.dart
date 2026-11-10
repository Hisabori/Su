import 'package:flutter/material.dart';
import '../theme/app_style.dart';
import '../services/diagnostic_log.dart';

/// Keeps the server's diagnostic available without making it the main guidance.
class LoginNotice extends StatelessWidget {
  const LoginNotice({super.key, required this.message});
  final String message;

  String get summary {
    final plain = message.replaceFirst(RegExp(r'\s*\(응답 코드: [^)]+\)\s*$'), '');
    if (plain.startsWith('요청이 거절되었습니다.')) {
      return '입력한 정보와 로그인 가능한 시간을 확인한 뒤 다시 시도해 주세요.';
    }
    return plain;
  }

  String? get nextStep {
    if (message.contains('로그인 권한') || message.contains('비활성')) {
      return '계정 상태는 관리자에게 확인해 주세요.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppStyle.isDark(context);
    final ink = dark ? const Color(0xFFFFDCA8) : const Color(0xFF523A18);
    final muted = dark ? const Color(0xFFD4C1A2) : const Color(0xFF665B49);
    return Semantics(
        liveRegion: true,
        container: true,
        explicitChildNodes: true,
        child: Container(
            key: const ValueKey('login-notice'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: dark ? const Color(0xFF302A20) : const Color(0xFFFFF5E5),
                border: Border.all(
                    color: dark
                        ? const Color(0xFF6E5940)
                        : const Color(0xFFE8D4AF)),
                borderRadius: BorderRadius.circular(20)),
            child: Material(
                type: MaterialType.transparency,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: dark
                                    ? const Color(0xFFFFDCA8)
                                    : const Color(0xFF76521C),
                                size: 22),
                            SizedBox(width: 9),
                            Expanded(
                                child: Text('로그인을 확인해 주세요',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: ink))),
                          ]),
                      const SizedBox(height: 10),
                      Text(summary,
                          style:
                              TextStyle(fontSize: 14, height: 1.5, color: ink)),
                      if (nextStep != null) ...[
                        const SizedBox(height: 6),
                        Text(nextStep!,
                            style: TextStyle(
                                fontSize: 13, height: 1.5, color: muted)),
                      ],
                      ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('오류 확인 번호',
                              style: TextStyle(fontSize: 12)),
                          children: [
                            SelectableText(DiagnosticLog.traceId,
                                style: const TextStyle(fontSize: 12))
                          ]),
                      if (summary != message)
                        ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            title: const Text('자세한 오류',
                                style: TextStyle(fontSize: 12)),
                            children: [
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(message,
                                      style: TextStyle(fontSize: 12)))
                            ]),
                    ]))));
  }
}
