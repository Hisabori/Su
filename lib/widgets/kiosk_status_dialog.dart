import 'package:flutter/material.dart';

class KioskStatusDialog extends StatelessWidget {
  const KioskStatusDialog(
      {super.key,
      required this.name,
      required this.status,
      required this.current,
      required this.capacity});
  final String name, status;
  final int? current, capacity;

  @override
  Widget build(BuildContext context) {
    final valid =
        current != null && current! >= 0 && capacity != null && capacity! > 0;
    final ratio = valid ? current! / capacity! : null;
    final scale = (MediaQuery.sizeOf(context).width / 524).clamp(.72, 1.0);
    final badgeColor = switch (status) {
      '비어있음' => const Color(0xFF32BDE8),
      '사용중' => const Color(0xFF218C55),
      '가득참' => const Color(0xFFEB7134),
      _ => const Color(0xFF687780),
    };
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 26 * scale, vertical: 24),
      backgroundColor: const Color(0xFFE9ECF1),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(36 * scale)),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 472),
          child: SingleChildScrollView(
              child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      26 * scale, 40 * scale, 26 * scale, 30 * scale),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('키오스크 현황',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 32 * scale,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 34 * scale),
                        Container(
                            padding: EdgeInsets.all(26 * scale),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(26 * scale)),
                            child: Column(children: [
                              Row(children: [
                                Expanded(
                                    child: Text(name,
                                        style: TextStyle(
                                            color: const Color(0xFF1574B6),
                                            fontSize: 26 * scale,
                                            fontWeight: FontWeight.w800))),
                                SizedBox(width: 10 * scale),
                                Flexible(
                                    fit: FlexFit.tight,
                                    child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 18 * scale,
                                                vertical: 12 * scale),
                                            decoration: BoxDecoration(
                                                color: badgeColor,
                                                borderRadius:
                                                    BorderRadius.circular(30)),
                                            child: Text(status,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 17 * scale,
                                                    fontWeight:
                                                        FontWeight.w800))))),
                              ]),
                              SizedBox(height: 24 * scale),
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: ExcludeSemantics(
                                      excluding: ratio == null,
                                      child: LinearProgressIndicator(
                                          value: (ratio ?? 0).clamp(0.0, 1.0),
                                          minHeight: 22 * scale,
                                          backgroundColor:
                                              const Color(0xFFE5E5E8),
                                          color: badgeColor,
                                          semanticsLabel: '키오스크 용량',
                                          semanticsValue: ratio == null
                                              ? null
                                              : '${(ratio * 100).toStringAsFixed(1)}%'))),
                              SizedBox(height: 16 * scale),
                              Text(
                                  ratio == null
                                      ? '용량 미확인'
                                      : '${(ratio * 100).toStringAsFixed(1)}%  ($current/$capacity)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: const Color(0xFF808187),
                                      fontSize: 20 * scale)),
                            ])),
                        SizedBox(height: 36 * scale),
                        SizedBox(
                            height: 68 * scale,
                            child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    side: const BorderSide(
                                        color: Color(0xFF94999E), width: 1.6),
                                    shape: const StadiumBorder()),
                                child: Text('닫기',
                                    style: TextStyle(
                                        fontFamily: 'NanumGothic',
                                        fontSize: 24 * scale,
                                        fontWeight: FontWeight.w800)))),
                      ])))),
    );
  }
}
