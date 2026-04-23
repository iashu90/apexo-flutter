import 'package:apexo/common_widgets/button_styles.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/core/theme/app_text_theme.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/features/login/login_controller.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoTextField;

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool rememberMe = false;

  static const _primary = Color(0xFF3B82F6);
  static const _card = Colors.white;
  static const _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    loginCtrl.emailField.clear();
    loginCtrl.passwordField.clear();
    loginCtrl.selectedTab(0);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: loginCtrl.loginError.stream,
      builder: (context, _) {
        return ScaffoldPage(
          padding: EdgeInsets.zero,
          bottomBar: loginCtrl.loginError().isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: InfoBar(
                    key: WK.loginErr,
                    title: Txt(txt('error')),
                    content: Txt(loginCtrl.loginError()),
                    severity: InfoBarSeverity.error,
                  ),
                )
              : null,
          content: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 1200;
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE0F2FE), Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    // Left panel (remove decoration/color)
                    Expanded(
                      child: _buildLeftImmersedPanel(compact),
                    ),
                    // Right panel (remove color)
                    Expanded(
                      child: _buildRightAuthPanel(compact),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLeftImmersedPanel(bool compact) {
    final titleSize = compact ? 40.0 : 48.0;
    final tt = AppTextTheme.textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 28, 40, 24),
        child:
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ColorFiltered(
                colorFilter: const ColorFilter.mode(_primary, BlendMode.srcIn),
                child: Image.asset(
                  'assets/drnowdentallogo.png',
                  width: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Welcome back,',
                style:
                    tt.displayLarge?.copyWith(fontSize: titleSize, height: 1.1),
              ),
              const SizedBox(height: 2),
              Text(
                'Dr. Nowfar Dental Clinic 👋',
                style: tt.displayLarge?.copyWith(
                    fontSize: titleSize, height: 1.1, color: _primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in to access your clinic dashboard',
                style: tt.headlineMedium?.copyWith(color: _textSecondary),
              ),
              const SizedBox(height: 20),
              _buildHeroVisual(),
              const SizedBox(height: 22),
              const Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _FeatureBadge(
                      icon: FluentIcons.calendar, label: 'Smart\nScheduling'),
                  _FeatureBadge(
                      icon: FluentIcons.contact_info,
                      label: 'Patient\nManagement'),
                  _FeatureBadge(
                      icon: FluentIcons.area_chart, label: 'Clinic\nAnalytics'),
                  _FeatureBadge(
                      icon: FluentIcons.shield, label: 'Secure\n& Reliable'),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '© 2026 Dr. Nowfear Dental Clinic. All rights reserved.',
                style: tt.bodySmall,
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildHeroVisual() {
    return Center(
      child: Container(
        width: 430,
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF1FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8AB2FF).withValues(alpha: 0.25),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
          border: Border.all(color: const Color(0xFFD9E6FF)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 215,
              height: 215,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD6E4FF)),
              ),
            ),
            const Icon(
              FluentIcons.shield,
              size: 126,
              color: Color(0xFF2D76F5),
            ),
            Positioned(
              left: 92,
              top: 106,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFFD9E8FF)),
                ),
                child: const Icon(
                  FluentIcons.page,
                  size: 36,
                  color: Color(0xFF2D76F5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightAuthPanel(bool compact) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: MStreamBuilder(
              streams: [
                loginCtrl.selectedTab.stream,
                loginCtrl.loginError.stream,
                loginCtrl.resetInstructionsSent.stream,
                loginCtrl.obscureText.stream,
                loginCtrl.loadingIndicator.stream,
              ],
              builder: (context, _) {
                final isLoginTab = loginCtrl.selectedTab() == 0;
                final isLoading = loginCtrl.loadingIndicator().isNotEmpty;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _tabPill(
                                active: isLoginTab,
                                icon: FluentIcons.lock,
                                text: 'Login',
                                onTap: () => loginCtrl.selectedTab(0),
                              ),
                              const SizedBox(width: 14),
                              _tabPill(
                                active: !isLoginTab,
                                icon: FluentIcons.password_field,
                                text: 'Reset password',
                                onTap: () => loginCtrl.selectedTab(1),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(FluentIcons.settings, size: 16),
                          onPressed: () => _openServerDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (isLoginTab) ...[
                      _fieldLabel('Username / Email'),
                      const SizedBox(height: 8),
                      _styledInput(
                        child: CupertinoTextField(
                          key: WK.emailField,
                          controller: loginCtrl.emailField,
                          placeholder: 'Enter your email or username',
                          textDirection: TextDirection.ltr,
                          enabled: !isLoading,
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(FluentIcons.contact,
                                size: 14, color: Color(0xFF7A8AA7)),
                          ),
                          decoration: null,
                          style: AppTextTheme.textTheme.bodyMedium,
                          onSubmitted: (_) => _fieldSubmit(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Password'),
                      const SizedBox(height: 8),
                      _styledInput(
                        child: CupertinoTextField(
                          key: WK.passwordField,
                          controller: loginCtrl.passwordField,
                          placeholder: 'Enter your password',
                          obscureText: loginCtrl.obscureText(),
                          textDirection: TextDirection.ltr,
                          enabled: !isLoading,
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(FluentIcons.lock,
                                size: 14, color: Color(0xFF7A8AA7)),
                          ),
                          suffix: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: IconButton(
                              icon: Icon(
                                loginCtrl.obscureText()
                                    ? FluentIcons.red_eye
                                    : FluentIcons.hide,
                                size: 14,
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () => loginCtrl
                                      .obscureText(!loginCtrl.obscureText()),
                            ),
                          ),
                          decoration: null,
                          style: AppTextTheme.textTheme.bodyMedium,
                          onSubmitted: (_) => _fieldSubmit(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Checkbox(
                            checked: rememberMe,
                            onChanged: (v) =>
                                setState(() => rememberMe = v ?? false),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remember me',
                            style: AppTextTheme.textTheme.labelLarge
                                ?.copyWith(color: const Color(0xFF5D6F94)),
                          ),
                          const Spacer(),
                          Button(
                            onPressed: isLoading
                                ? null
                                : () => loginCtrl.selectedTab(1),
                            child: Text(
                              'Forgot password?',
                              style: AppTextTheme.textTheme.labelLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2B75EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          key: WK.btnLogin,
                          label: isLoading ? 'Please wait...' : 'Login',
                          onPressed: isLoading ? null : loginCtrl.loginButton,
                          expanded: true,
                          leading: const Icon(FluentIcons.forward, size: 14),
                        ),
                      ),
                      if (isLoading) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD3E2FF)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: ProgressRing(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  loginCtrl.loadingIndicator(),
                                  style: AppTextTheme.textTheme.bodySmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF35507F)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (loginCtrl.loginError().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        FilledButton(
                          key: WK.btnProceedOffline,
                          onPressed: () => loginCtrl.loginButton(false),
                          style: greyButtonStyle,
                          child: const SizedBox(
                            width: double.infinity,
                            child: Text(
                              'Proceed Offline',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      _fieldLabel('Username / Email'),
                      const SizedBox(height: 8),
                      _styledInput(
                        child: CupertinoTextField(
                          key: WK.emailField,
                          controller: loginCtrl.emailField,
                          placeholder: 'Enter your email',
                          textDirection: TextDirection.ltr,
                          enabled: !isLoading,
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(FluentIcons.contact,
                                size: 14, color: Color(0xFF7A8AA7)),
                          ),
                          decoration: null,
                          style: AppTextTheme.textTheme.bodyMedium,
                          onSubmitted: (_) => _fieldSubmit(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InfoBar(
                        title: loginCtrl.resetInstructionsSent()
                            ? Txt(key: WK.msgSentReset, txt('beenSent'))
                            : Txt(key: WK.msgWillSendReset, txt('youLLGet')),
                        severity: loginCtrl.resetInstructionsSent()
                            ? InfoBarSeverity.success
                            : InfoBarSeverity.info,
                      ),
                      const SizedBox(height: 14),
                      if (!loginCtrl.resetInstructionsSent())
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            key: WK.btnResetPassword,
                            label:
                                isLoading ? 'Please wait...' : 'Reset password',
                            onPressed: isLoading ? null : loginCtrl.resetButton,
                            expanded: true,
                            leading: const Icon(FluentIcons.password_field,
                                size: 14),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(FluentIcons.shield,
                              size: 14, color: Color(0xFF1D63DF)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your data is protected with enterprise-grade security',
                              style: AppTextTheme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF3D5587)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabPill({
    required bool active,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? _primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 13, color: active ? _primary : const Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Text(
                text,
                style: AppTextTheme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: active ? _primary : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text,
        style:
            AppTextTheme.textTheme.labelLarge?.copyWith(color: _textSecondary));
  }

  Widget _styledInput({required Widget child}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(child: child),
    );
  }

  Future<void> _openServerDialog(BuildContext context) async {
    final serverController =
        TextEditingController(text: loginCtrl.urlField.text);
    bool obscureUrl = true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setLocalState) {
            return ContentDialog(
              title: const Text('Server URL'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoTextField(
                    key: WK.serverField,
                    controller: serverController,
                    textDirection: TextDirection.ltr,
                    obscureText: obscureUrl,
                    obscuringCharacter: '*',
                    placeholder: 'https://[pocketbase server]',
                    suffix: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: IconButton(
                        icon: Icon(
                            obscureUrl ? FluentIcons.red_eye : FluentIcons.hide,
                            size: 16),
                        onPressed: () =>
                            setLocalState(() => obscureUrl = !obscureUrl),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'URL is masked by default to prevent shoulder-surfing.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Txt(txt('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Txt(txt('save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      loginCtrl.urlField.text = serverController.text.trim();
    }
  }

  void _fieldSubmit() {
    if (loginCtrl.loadingIndicator().isNotEmpty) return;
    if (loginCtrl.selectedTab() == 0) {
      loginCtrl.loginButton();
    } else if (loginCtrl.selectedTab() == 1) {
      loginCtrl.resetButton();
    }
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 122,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD7E5FF)),
            ),
            child: Icon(icon, size: 17, color: const Color(0xFF2E74EE)),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: const Color(0xFF2E446F),
            ),
          ),
        ],
      ),
    );
  }
}
