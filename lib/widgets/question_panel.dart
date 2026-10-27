import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_style.dart';
import '../theme/glass_surface.dart';

class QuestionPanel extends StatelessWidget {
  const QuestionPanel(
      {super.key,
      required this.prompt,
      required this.current,
      required this.total,
      required this.speaking,
      required this.listening,
      required this.onReplay,
      required this.onSpeech,
      required this.onYes,
      required this.onNo,
      required this.onSettings,
      required this.onDevice,
      this.media,
      this.mediaStatus,
      this.speechUnavailable = false});
  final String prompt;
  final Widget? media;
  final String? mediaStatus;
  final bool speechUnavailable;
  final int current, total;
  final bool speaking, listening;
  final VoidCallback onReplay, onSpeech, onSettings, onDevice;
  final VoidCallback? onYes, onNo;

  Widget roundButton(String asset, String label, VoidCallback action) =>
      Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 8)]),
          child: Semantics(
              label: label,
              child: Tooltip(
                  message: label,
                  excludeFromSemantics: true,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: action,
                      icon: Image.asset(asset,
                          excludeFromSemantics: true,
                          width: 42, height: 42, fit: BoxFit.contain)))));

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final width = math.min(bounds.maxWidth, 560.0);
        final scale = (width / 414).clamp(.75, 1.25);
        final minHeight = math.max(bounds.maxHeight, 840 * scale + 20);
        final fraction = (current / total).clamp(0.0, 1.0);
        final border = Border.all(
            color: (AppStyle.isBeta(context)
                ? AppStyle.line
                : const Color(0xFF596268)),
            width: AppStyle.isBeta(context) ? 1.4 : 2.3);
        final textStyle = TextStyle(
            fontSize: 21 * scale,
            fontWeight: FontWeight.w800,
            color: AppStyle.isBeta(context) ? AppStyle.ink : Colors.black,
            height: 1.25);
        Widget answerButton(String text, Color color, VoidCallback? callback) =>
            Expanded(
                child: SizedBox(
                    height: 66 * scale,
                    child: FilledButton(
                        onPressed: callback,
                        style: FilledButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            textStyle: TextStyle(
                                fontFamily: 'NanumGothic',
                                fontSize: 21 * scale,
                                fontWeight: FontWeight.w800),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    (AppStyle.isBeta(context) ? 24 : 11) *
                                        scale))),
                        child: Text(text))));
        return SingleChildScrollView(
            child: Center(
                child: SizedBox(
                    width: width,
                    height: minHeight,
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                        child: Column(children: [
                          SizedBox(height: 20 * scale),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                roundButton('assets/images/Icon_set.png', '설정',
                                    onSettings),
                                roundButton('assets/images/icon_device.png',
                                    '기기 상태', onDevice),
                              ]),
                          SizedBox(height: 18 * scale),
                          Stack(alignment: Alignment.center, children: [
                            Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 60 * scale),
                                height: 44 * scale,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30)),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text('질문 $current / $total',
                                          style: textStyle.copyWith(
                                              fontSize: 16 * scale)),
                                      Text('+${total - current} 남음',
                                          style: textStyle.copyWith(
                                              fontSize: 14 * scale)),
                                    ])),
                            if (!speaking)
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: roundButton(
                                      'assets/images/Icon_replay.png',
                                      '다시 듣기',
                                      onReplay)),
                          ]),
                          SizedBox(height: 16 * scale),
                          Stack(alignment: Alignment.topCenter, children: [
                            GlassBox(
                                margin: EdgeInsets.only(top: 44 * scale),
                                height: (media == null ? 480 : 520) * scale,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    color: AppStyle.isBeta(context)
                                        ? const Color(0xBFFFFFFF)
                                        : Colors.white,
                                    border: border,
                                    borderRadius: BorderRadius.circular(
                                        (AppStyle.isBeta(context) ? 28 : 20) *
                                            scale),
                                    boxShadow: AppStyle.isBeta(context)
                                        ? AppStyle.shadow
                                        : const [
                                            BoxShadow(
                                                color: Color(0x26000000),
                                                blurRadius: 9,
                                                offset: Offset(0, 4))
                                          ]),
                                padding: EdgeInsets.fromLTRB(24 * scale,
                                    64 * scale, 24 * scale, 26 * scale),
                                child: Column(children: [
                                  Expanded(
                                      child: media == null
                                          ? Center(
                                              child: SingleChildScrollView(
                                                  child: Text(prompt,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: textStyle)))
                                          : SingleChildScrollView(
                                              child: Column(children: [
                                              media!,
                                              SizedBox(height: 14 * scale),
                                              Text(prompt,
                                                  textAlign: TextAlign.center,
                                                  style: textStyle.copyWith(
                                                      fontSize: 18 * scale)),
                                            ]))),
                                  SizedBox(height: 24 * scale),
                                  SizedBox(
                                      width: double.infinity,
                                      height: 60 * scale,
                                      child: OutlinedButton.icon(
                                          onPressed: speaking || media != null
                                              ? null
                                              : onSpeech,
                                          style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                  color: AppStyle.isBeta(context)
                                                      ? AppStyle.line
                                                      : const Color(0xFF596268),
                                                  width: AppStyle.isBeta(context)
                                                      ? 1.4
                                                      : 2.3),
                                              disabledForegroundColor:
                                                  Colors.black,
                                              foregroundColor: Colors.black,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(
                                                      15 * scale))),
                                          icon: media != null
                                              ? const Icon(Icons.ondemand_video,
                                                  color: Colors.black)
                                              : Image.asset(
                                                  speaking
                                                      ? 'assets/images/Icon_speak.png'
                                                      : 'assets/images/Icon_mic.png',
                                                  width: 30 * scale,
                                                  height: 30 * scale),
                                          label: Text(
                                              media != null
                                                  ? (mediaStatus ?? '영상을 시청해 주세요.')
                                                  : speaking
                                                      ? '질문 읽는중…'
                                                      : listening
                                                          ? '답변 듣는중…'
                                                          : speechUnavailable
                                                              ? '음성 인식을 사용할 수 없어요'
                                                              : '음성 버튼을 눌러주세요.',
                                              style: textStyle.copyWith(fontSize: (speaking || listening ? 17 : 14) * scale)))),
                                  SizedBox(
                                      height: media == null ? 26 * scale : 0),
                                  // Reserve the answer area while speaking to avoid moving the card.
                                  SizedBox(
                                      height: media == null ? 66 * scale : 0,
                                      child: speaking || media != null
                                          ? null
                                          : Row(children: [
                                              answerButton(
                                                  '예',
                                                  (AppStyle.isBeta(context)
                                                      ? AppStyle.navy
                                                      : const Color(
                                                          0xFF104B83)),
                                                  onYes),
                                              SizedBox(width: 18 * scale),
                                              answerButton(
                                                  '아니요',
                                                  const Color(0xFFEB7134),
                                                  onNo),
                                            ])),
                                ])),
                            Image.asset('assets/images/chr_rab.png',
                                width: 92 * scale, height: 92 * scale),
                          ]),
                          const Spacer(),
                          Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 12 * scale),
                              child: LayoutBuilder(
                                  builder: (context, bar) =>
                                      Stack(clipBehavior: Clip.none, children: [
                                        ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: LinearProgressIndicator(
                                                value: fraction,
                                                minHeight: 18 * scale,
                                                color: AppStyle.isBeta(context)
                                                    ? AppStyle.teal
                                                    : const Color(0xFF18832B),
                                                backgroundColor:
                                                    AppStyle.isBeta(context)
                                                        ? AppStyle.line
                                                        : const Color(
                                                            0xFFA6A6A6))),
                                        Positioned(
                                            left: ((bar.maxWidth - 62 * scale) *
                                                    fraction)
                                                .clamp(0, bar.maxWidth),
                                            bottom: -1 * scale,
                                            child: Image.asset(
                                                'assets/images/chr_t.png',
                                                width: 62 * scale)),
                                      ]))),
                          SizedBox(height: 10 * scale),
                          Text('진행률 $current/$total',
                              style: textStyle.copyWith(fontSize: 20 * scale)),
                          SizedBox(height: 28 * scale),
                        ])))));
      });
}
