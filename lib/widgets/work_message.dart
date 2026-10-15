import 'package:flutter/material.dart';

/// Responsive reconstruction of the APK's AppMessageScreenLayout.
class WorkMessage extends StatelessWidget {
  const WorkMessage({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight &&
              constraints.maxWidth >= 600;
          final scale =
              (MediaQuery.sizeOf(context).shortestSide / 390).clamp(0.8, 1.08);
          final logo = Image.asset('assets/images/logo.png',
              height: (landscape ? 118 : 138) * scale,
              fit: BoxFit.contain,
              semanticLabel: '수호천사');
          final message = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  textAlign: landscape ? TextAlign.start : TextAlign.center,
                  style: TextStyle(
                      color: const Color(0xFF111111),
                      fontSize: 32 * scale,
                      fontWeight: FontWeight.w600,
                      height: 1.4)),
              SizedBox(height: 32 * scale),
              ...children,
            ],
          );
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 64).clamp(0, double.infinity)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: landscape
                      ? Row(children: [
                          Expanded(child: logo),
                          SizedBox(width: 40 * scale),
                          Expanded(flex: 2, child: message),
                        ])
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          logo,
                          SizedBox(height: 40 * scale),
                          message,
                        ]),
                ),
              ),
            ),
          );
        },
      );
}
