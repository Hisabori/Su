import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_style.dart';

String completionTime(DateTime value) =>
    '${value.hour < 12 ? '오전' : '오후'} ${value.hour % 12 == 0 ? 12 : value.hour % 12}:${value.minute.toString().padLeft(2, '0')}';

class CompletionPanel extends StatelessWidget {
  const CompletionPanel(
      {super.key,
      required this.name,
      required this.start,
      required this.end,
      required this.onHistory,
      required this.onCheckout,
      required this.onDevice,
      this.onCommunity,
      this.scheduled = false,
      this.checkoutLabel = '퇴근하기'});
  final String? name;
  final DateTime? start, end;
  final VoidCallback onHistory;
  final VoidCallback? onDevice, onCommunity;
  final String checkoutLabel;
  final VoidCallback? onCheckout;

  /// A server status response alone does not prove a successful result save.
  final bool scheduled;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final width = math.min(bounds.maxWidth, 600.0);
        final scale = (width / 524).clamp(.7, 1.1);
        final today = DateTime.now();
        final prefix = start == null ||
                (start!.year == today.year &&
                    start!.month == today.month &&
                    start!.day == today.day)
            ? '오늘은 '
            : '${start!.month}월 ${start!.day}일은 ';
        final style = TextStyle(
            fontFamily: 'NanumGothic',
            fontSize: 29 * scale,
            fontWeight: FontWeight.w800,
            height: 1.6,
            color: AppStyle.isBeta(context) ? AppStyle.ink : Colors.black);
        final highlight =
            AppStyle.isBeta(context) ? AppStyle.teal : const Color(0xFF5A83A7);
        return ColoredBox(
            color: (AppStyle.isBeta(context)
                ? Colors.transparent
                : const Color(0xFFEDF1F6)),
            child: SingleChildScrollView(
                child: Center(
                    child: SizedBox(
                        width: width,
                        height: math.max(bounds.maxHeight, 1100 * scale),
                        child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 64 * scale),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: 20 * scale),
                                  Row(children: [
                                    if (onCommunity != null)
                                      IconButton(
                                          tooltip: '커뮤니티',
                                          onPressed: onCommunity,
                                          icon:
                                              const Icon(Icons.forum_outlined)),
                                    const Spacer(),
                                    SizedBox(
                                        width: 50 * scale,
                                        height: 50 * scale,
                                        child: IconButton(
                                            padding: EdgeInsets.zero,
                                            tooltip: '기기 상태',
                                            onPressed: onDevice,
                                            icon: Image.asset(
                                                'assets/images/icon_device.png',
                                                fit: BoxFit.contain))),
                                  ]),
                                  SizedBox(height: 44 * scale),
                                  Image.asset('assets/images/logo.png',
                                      height: 90 * scale,
                                      fit: BoxFit.contain,
                                      semanticLabel: '수호천사'),
                                  SizedBox(height: 98 * scale),
                                  Text.rich(
                                      TextSpan(children: [
                                        if (name != null &&
                                            name!.trim().isNotEmpty) ...[
                                          TextSpan(
                                              text: name!.trim(),
                                              style:
                                                  TextStyle(color: highlight)),
                                          const TextSpan(text: ' 님,\n'),
                                        ],
                                        const TextSpan(text: '수고하셨습니다.'),
                                      ]),
                                      style: style),
                                  SizedBox(height: 52 * scale),
                                  Text.rich(
                                      TextSpan(children: [
                                        TextSpan(text: prefix),
                                        if (start != null)
                                          TextSpan(
                                              text: completionTime(start!),
                                              style:
                                                  TextStyle(color: highlight))
                                        else
                                          TextSpan(
                                              text: '시각 미확인',
                                              style:
                                                  TextStyle(color: highlight)),
                                        TextSpan(
                                            text: scheduled
                                                ? ' 근무 시작,\n'
                                                : '에\n일을 시작 하셨고,\n'),
                                        if (end != null)
                                          TextSpan(
                                              text: completionTime(end!),
                                              style:
                                                  TextStyle(color: highlight))
                                        else
                                          TextSpan(
                                              text: '시각 미확인',
                                              style:
                                                  TextStyle(color: highlight)),
                                        TextSpan(
                                            text: scheduled
                                                ? '에 일을\n마무리할 예정입니다.'
                                                : '에 일을\n마무리 하셨습니다.'),
                                      ]),
                                      style: style),
                                  const Spacer(),
                                  Semantics(
                                      liveRegion: true,
                                      child: Text(
                                          scheduled
                                              ? '예정된 근무 시간입니다. 완료 기록은 근무기록에서 확인해 주세요.'
                                              : '서버에 작업 결과를 저장했습니다.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF616970)))),
                                  SizedBox(height: 14 * scale),
                                  SizedBox(
                                      height: 65 * scale,
                                      child: FilledButton(
                                          onPressed: onHistory,
                                          style: FilledButton.styleFrom(
                                              backgroundColor: (AppStyle.isBeta(
                                                      context)
                                                  ? AppStyle.navy
                                                  : const Color(0xFF104B83)),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          26 * scale))),
                                          child: Text('근무기록 자세히 보기',
                                              style: TextStyle(
                                                  fontFamily: 'NanumGothic',
                                                  fontSize: 23 * scale,
                                                  fontWeight:
                                                      FontWeight.w800)))),
                                  SizedBox(height: 24 * scale),
                                  SizedBox(
                                      height: 65 * scale,
                                      child: OutlinedButton(
                                          onPressed: onCheckout,
                                          style: OutlinedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                                  const Color(0xFF505050),
                                              side: BorderSide(
                                                  color:
                                                      AppStyle.isBeta(context)
                                                          ? AppStyle.line
                                                          : const Color(
                                                              0xFF96999D)),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          26 * scale))),
                                          child: Text(checkoutLabel,
                                              style: TextStyle(
                                                  fontFamily: 'NanumGothic',
                                                  fontSize: 23 * scale,
                                                  fontWeight:
                                                      FontWeight.w800)))),
                                  SizedBox(height: 40 * scale),
                                ]))))));
      });
}
