import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/passkey_service.dart';
import '../services/app_preferences.dart';
import '../services/session_restore_service.dart';
import 'work_screen.dart';
import '../widgets/login_notice.dart';
import '../theme/app_style.dart';
import '../theme/glass_surface.dart';
import '../theme/appearance_scope.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final api = ApiService(communityLogin: true);
  final passkeys = PasskeyService();
  final preferences = AppPreferences();
  bool passkeyAvailable = false, passkeyConfigured = false;
  bool busy = false;
  bool autoLogin = true, restoringSession = false, sessionRetry = false;
  bool hidePassword = true;
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
      final enabled = await preferences.autoLoginEnabled();
      if (mounted) {
        setState(() {
          passkeyAvailable = state['supported'] == true;
          passkeyConfigured = state['enrolled'] == true;
          autoLogin = enabled;
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
    if (busy) return;
    setState(() {
      busy = true;
      restoringSession = true;
      sessionRetry = false;
      error = null;
    });
    try {
      final enabled = await preferences.autoLoginEnabled();
      if (mounted) setState(() => autoLogin = enabled);
      final result =
          await SessionRestoreService(api: api, preferences: preferences)
              .restore();
      if (!mounted) return;
      if (result == SessionRestoreResult.expired) {
        setState(() => error = '저장된 로그인이 만료되었습니다. 다시 로그인해 주세요.');
        return;
      }
      if (result != SessionRestoreResult.restored) return;
      setState(() => restoringSession = false);
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const WorkScreen()));
    } catch (_) {
      if (mounted) {
        setState(() {
          error = '자동 로그인을 확인하지 못했습니다. 인터넷 연결을 확인하고 다시 시도하거나 비밀번호로 로그인해 주세요.';
          sessionRetry = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          restoringSession = false;
        });
      }
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
      sessionRetry = false;
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

  Future<void> setAutoLogin(bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await preferences.setAutoLoginEnabled(value);
      if (mounted) {
        setState(() {
          autoLogin = value;
          if (!value) sessionRetry = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = '자동 로그인 설정을 저장하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget loginForm(double width, double scale) {
    final beta = AppStyle.isBeta(context);
    final labelStyle = TextStyle(
        fontSize: (18 * scale).clamp(16, 20),
        color: const Color(0xFF636363),
        fontWeight: FontWeight.w600);
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(10 * scale),
        borderSide:
            beta ? const BorderSide(color: AppStyle.line) : BorderSide.none);
    InputDecoration decoration(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: beta ? const Color(0x99FFFFFF) : const Color(0xFFE9E9EF),
          hintStyle: TextStyle(
              color: const Color(0xFFA0A0A0),
              fontSize: (13 * scale).clamp(11, 16)),
          contentPadding: EdgeInsets.symmetric(
              horizontal: 14 * scale, vertical: 10 * scale),
          border: border,
          enabledBorder: border,
          focusedBorder: beta
              ? border.copyWith(
                  borderSide:
                      const BorderSide(color: AppStyle.teal, width: 1.5))
              : border,
        );
    final helper = <Widget>[
      const SizedBox(height: 8),
      const Text('패스키는 로그인 후 열쇠 버튼에서 설정할 수 있습니다. 세션 만료 시 비밀번호 로그인이 필요합니다.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      const SizedBox(height: 14),
      const Text('홈 화면에 설치: Safari 공유 → 홈 화면에 추가 / Chrome 메뉴 → 앱 설치',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      const Text('v1.15.0 · 빌드 27',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
      const SizedBox(height: 8),
      const Text('로그인과 결과 저장에는 인터넷 연결이 필요합니다.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    ];
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
                  autocorrect: false,
                  enableSuggestions: false,
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
                  obscureText: hidePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: TextStyle(
                      fontSize: (16 * scale).clamp(14, 18),
                      color: const Color(0xFF616161)),
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => login(),
                  decoration: decoration('비밀번호를 입력하세요.').copyWith(
                      suffixIcon: IconButton(
                          tooltip: hidePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                          onPressed: busy
                              ? null
                              : () =>
                                  setState(() => hidePassword = !hidePassword),
                          icon: Icon(hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined))),
                )),
            CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('자동 로그인'),
                subtitle: const Text('서버에서 확인된 로그인 상태로 다시 접속합니다.'),
                value: autoLogin,
                onChanged:
                    busy ? null : (value) => setAutoLogin(value == true)),
            if (restoringSession)
              Semantics(liveRegion: true, child: const Text('자동 로그인 확인 중…')),
            if (sessionRetry && autoLogin)
              OutlinedButton(
                  onPressed: busy ? null : restoreSession,
                  child: const Text('자동 로그인 다시 시도')),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: beta
                      ? LoginNotice(message: error!)
                      : Semantics(
                          liveRegion: true,
                          child: Text(error!,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)))),
            SizedBox(height: 28 * scale),
            SizedBox(
                height: (54 * scale).clamp(46, 58),
                child: FilledButton(
                  key: const ValueKey('password-login'),
                  onPressed: busy ? null : login,
                  style: FilledButton.styleFrom(
                      backgroundColor:
                          beta ? AppStyle.navy : const Color(0xFF104B83),
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
              if (beta)
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title:
                        const Text('설치·로그인 안내', style: TextStyle(fontSize: 13)),
                    children: helper)
              else
                ...helper,
            ],
            const SizedBox(height: 14),
            TextButton.icon(
                onPressed: AppearanceScope.of(context)?.saving == true
                    ? null
                    : () async {
                        final appearance = AppearanceScope.of(context);
                        if (appearance == null) return;
                        final saved =
                            await appearance.setEnabled(!appearance.enabled);
                        if (!saved && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('화면 설정을 저장하지 못했습니다. 다시 시도해 주세요.')));
                        }
                      },
                icon: Icon(beta ? Icons.toggle_off : Icons.toggle_on),
                label: Text(beta ? '레거시 모드 켜기' : '레거시 모드 끄기')),
          ],
        )));
  }

  Widget betaLayout(BuildContext context) => Scaffold(
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850 ||
              (constraints.maxWidth >= 700 &&
                  constraints.maxWidth > constraints.maxHeight);
          final short = constraints.maxHeight < 600;
          final scale =
              (math.min(constraints.maxWidth, constraints.maxHeight) / 390)
                  .clamp(.85, 1.05);
          final cardWidth =
              math.min(constraints.maxWidth - 32, wide ? 440.0 : 460.0);
          final brand = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png',
                    height: wide ? (short ? 72 : 134) : 64,
                    fit: BoxFit.contain,
                    semanticLabel: '수호천사'),
                SizedBox(height: wide ? 24 : 12),
                Text(wide ? '함께하는 근무,\n더 편안한 하루' : '오늘의 근무를 편안하게',
                    textAlign: wide ? TextAlign.start : TextAlign.center,
                    style: TextStyle(
                        fontSize: wide ? (short ? 24 : 34) : 22,
                        height: 1.4,
                        fontWeight: FontWeight.w800,
                        color: AppStyle.navy)),
                if (wide) const SizedBox(height: 12),
                if (wide)
                  Text('오늘의 질문부터 근무 마무리까지\n수호천사가 함께합니다.',
                      textAlign: wide ? TextAlign.start : TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, height: 1.7, color: AppStyle.muted)),
              ]);
          final card = GlassSurface(
              width: cardWidth,
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('반가워요',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppStyle.ink)),
                    const SizedBox(height: 8),
                    const Text('계정으로 로그인해 근무를 이어가세요.',
                        style: TextStyle(
                            fontSize: 13, color: AppStyle.muted, height: 1.5)),
                    const SizedBox(height: 26),
                    loginForm(cardWidth - 48, scale),
                  ]));
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: wide
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                  Expanded(
                                      child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 48),
                                          child: brand)),
                                  card,
                                ])
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              brand,
                              const SizedBox(height: 20),
                              card
                            ]),
                    ))),
          );
        })),
      );
  Widget classicLayout(BuildContext context) => Scaffold(
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
  @override
  Widget build(BuildContext context) =>
      AppStyle.isBeta(context) ? betaLayout(context) : classicLayout(context);
}
