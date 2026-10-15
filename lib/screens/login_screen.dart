import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/passkey_service.dart';
import 'work_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final api = ApiService();
  final passkeys = PasskeyService();
  bool passkeyAvailable = false, passkeyConfigured = false;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    refreshPasskeyStatus();
    restoreSession();
  }

  Future<void> refreshPasskeyStatus() async {
    try {
      final state = await passkeys.status();
      if (mounted) {
        setState(() {
          passkeyAvailable = state['supported'] == true;
          passkeyConfigured = state['enrolled'] == true;
        });
      }
    } catch (_) {
      /* Password login remains available when WebAuthn is unavailable. */
    }
  }

  Future<void> loginWithPasskey() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await passkeys.unlock(api);
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const WorkScreen()));
    } catch (e) {
      if (mounted) {
        setState(
            () => error = e is ApiFailure ? e.message : '패스키로 로그인하지 못했습니다.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
      await refreshPasskeyStatus();
    }
  }

  Future<void> restoreSession() async {
    setState(() => busy = true);
    try {
      final token = await api.tokens.read();
      if (token == null || token.isEmpty) return;
      await api.validateToken();
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const WorkScreen()));
    } catch (_) {
      /* Network failure keeps local credentials for a later attempt. */
    } finally {
      if (mounted) setState(() => busy = false);
      await refreshPasskeyStatus();
    }
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    api.close();
    super.dispose();
  }

  Future<void> login() async {
    if (busy) return;
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = '아이디와 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.login(username.text.trim(), password.text);
      password.clear();
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const WorkScreen()));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiFailure ? e.message : '연결에 실패했습니다. 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
      await refreshPasskeyStatus();
    }
  }

  Widget loginForm(double width, double scale) {
    final labelStyle = TextStyle(
        fontSize: (18 * scale).clamp(16, 20),
        color: const Color(0xFF636363),
        fontWeight: FontWeight.w600);
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(10 * scale),
        borderSide: BorderSide.none);
    InputDecoration decoration(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFE9E9EF),
          hintStyle: TextStyle(
              color: const Color(0xFFA0A0A0),
              fontSize: (13 * scale).clamp(11, 16)),
          contentPadding: EdgeInsets.symmetric(
              horizontal: 14 * scale, vertical: 10 * scale),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        );
    return SizedBox(
        width: width,
        child: AutofillGroup(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('아이디', style: labelStyle),
            SizedBox(height: 8 * scale),
            Semantics(
                label: '아이디',
                child: TextField(
                  controller: username,
                  enabled: !busy,
                  style: TextStyle(
                      fontSize: (16 * scale).clamp(14, 18),
                      color: const Color(0xFF616161)),
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: decoration('아이디를 입력하세요.'),
                )),
            SizedBox(height: 18 * scale),
            Text('비밀번호', style: labelStyle),
            SizedBox(height: 8 * scale),
            Semantics(
                label: '비밀번호',
                child: TextField(
                  controller: password,
                  enabled: !busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: TextStyle(
                      fontSize: (16 * scale).clamp(14, 18),
                      color: const Color(0xFF616161)),
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => login(),
                  decoration: decoration('비밀번호를 입력하세요.'),
                )),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                      liveRegion: true,
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)))),
            SizedBox(height: 28 * scale),
            SizedBox(
                height: (54 * scale).clamp(46, 58),
                child: FilledButton(
                  key: const ValueKey('password-login'),
                  onPressed: busy ? null : login,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF104B83),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF7A9BBC),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10 * scale)),
                      textStyle: TextStyle(
                          fontFamily: 'NanumGothic',
                          fontSize: (17 * scale).clamp(15, 19),
                          fontWeight: FontWeight.w500)),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('로그인'),
                )),
            if (kIsWeb) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                  key: const ValueKey('passkey-login'),
                  onPressed: busy || !passkeyAvailable || !passkeyConfigured
                      ? null
                      : loginWithPasskey,
                  icon: const Icon(Icons.key),
                  label: const Text('이 기기 패스키로 로그인')),
              const SizedBox(height: 8),
              const Text(
                  '패스키는 로그인 후 열쇠 버튼에서 설정할 수 있습니다. 세션 만료 시 비밀번호 로그인이 필요합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 14),
              const Text('홈 화면에 설치: Safari 공유 → 홈 화면에 추가 / Chrome 메뉴 → 앱 설치',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              const Text('로그인과 결과 저장에는 인터넷 연결이 필요합니다.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ],
          ],
        )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final scale =
              (math.min(constraints.maxWidth, constraints.maxHeight) / 390)
                  .clamp(0.8, 1.08);
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final padding = (20 * scale).clamp(14.0, 26.0);
          final formWidth = math.min(
              constraints.maxWidth - padding * 2,
              landscape
                  ? (constraints.maxWidth * .42).clamp(280.0, 420.0)
                  : (constraints.maxWidth * .84).clamp(260.0, 430.0));
          final logoHeight = (180 * scale).clamp(140.0, 210.0);
          final logo = Image.asset('assets/images/logo.png',
              height:
                  landscape ? (logoHeight * 1.18).clamp(170, 250) : logoHeight,
              fit: BoxFit.contain,
              semanticLabel: '수호천사');
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Center(
                child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: landscape
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                          Expanded(child: Center(child: logo)),
                          SizedBox(width: (30 * scale).clamp(20, 40)),
                          loginForm(formWidth, scale),
                        ])
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      logo,
                      SizedBox(height: 22 * scale),
                      loginForm(formWidth, scale),
                    ]),
            )),
          );
        })),
      );
}
