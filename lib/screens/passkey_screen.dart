import '../widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/passkey_service.dart';
import '../services/token_storage_service.dart';

class PasskeyScreen extends StatefulWidget {
  const PasskeyScreen({super.key});
  @override
  State<PasskeyScreen> createState() => _PasskeyScreenState();
}

class _PasskeyScreenState extends State<PasskeyScreen> {
  final passkeys = PasskeyService();
  final tokens = TokenStorageService();
  Map<String, dynamic>? state;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await passkeys.status();
      if (mounted) setState(() => state = result);
    } catch (e) {
      if (mounted) {
        setState(
            () => message = e is ApiFailure ? e.message : '설정을 불러오지 못했습니다.');
      }
    }
  }

  Future<void> run(Future<void> Function() action, String success) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      await load();
      if (mounted) setState(() => message = success);
    } catch (e) {
      if (mounted) {
        setState(() =>
            message = e is ApiFailure ? e.message : '패스키 설정을 완료하지 못했습니다.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> disable() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('이 기기의 패스키 로그인을 해제할까요?'),
              content: const Text(
                  '로그인 정보는 기존 기기 저장 방식으로 돌아갑니다. iCloud 또는 비밀번호 관리자의 패스키는 자동 삭제되지 않습니다.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('해제'))
              ],
            ));
    if (ok == true && mounted) {
      await run(() => passkeys.disable(tokens), '이 기기의 패스키 로그인을 해제했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('패스키 로그인 설정')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const AppIcon(AppIconKind.passkey, size: 64),
                    const SizedBox(height: 20),
                    const Text('이 기기의 로그인 세션을 패스키로 암호화합니다. 비밀번호는 저장하지 않습니다.'),
                    const SizedBox(height: 12),
                    const Text(
                        '새로고침하거나 앱 창을 완전히 닫았다 열면 패스키 인증이 필요합니다. 다른 앱으로 전환하기 전에는 작업 화면의 앱 잠그기를 눌러 주세요. 서버 세션이 만료되거나 서버에서 로그아웃되면 비밀번호로 다시 로그인한 뒤 로그인 정보를 갱신해 주세요.'),
                    const SizedBox(height: 12),
                    const Text(
                        '이 브라우저의 데이터와 패스키가 모두 있어야 합니다. 패스키만 다른 기기로 동기화해도 로그인 세션은 옮겨지지 않습니다.'),
                    const SizedBox(height: 24),
                    if (state == null && message == null)
                      const Center(child: CircularProgressIndicator()),
                    if (state?['supported'] == false) ...[
                      Text(kIsWeb
                          ? '이 브라우저에서는 패스키를 사용할 수 없습니다. iPhone Safari 또는 지원되는 브라우저에서 열어 주세요.'
                          : '이 앱 설치본은 아직 패스키 연동을 지원하지 않습니다. iPhone Safari 또는 홈 화면 웹 앱에서 사용해 주세요.'),
                      TextButton(
                          onPressed: () => launchUrl(
                              Uri.parse('https://suho-angel.vercel.app/'),
                              mode: LaunchMode.externalApplication),
                          child: const Text('웹 버전 열기')),
                    ],
                    if (state?['supported'] == true &&
                        state?['enrolled'] != true)
                      FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => run(() => passkeys.enroll(tokens, '수호천사'),
                                  '패스키 로그인을 설정했습니다.'),
                          icon: const AppIcon(AppIconKind.passkey),
                          label: const Text('이 기기에 패스키 설정')),
                    if (state?['enrolled'] == true) ...[
                      const Text('이 기기에 패스키 로그인이 설정돼 있습니다.'),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: busy
                              ? null
                              : () => run(() => passkeys.refresh(tokens),
                                  '패스키의 로그인 정보를 갱신했습니다.'),
                          child: const Text('로그인 정보 갱신')),
                      TextButton(
                          onPressed: busy ? null : disable,
                          child: const Text('이 기기의 패스키 로그인 해제')),
                    ],
                    if (busy)
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator())),
                    if (message != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Semantics(
                              liveRegion: true, child: Text(message!))),
                  ],
                ))),
      ));
}
