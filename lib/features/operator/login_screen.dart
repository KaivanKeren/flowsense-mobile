import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../data/auth/fake_auth_api.dart';
import '../../domain/app_mode.dart';
import '../../state/app_mode_providers.dart';
import '../../state/auth_providers.dart';

/// The operator console's front door.
///
/// One full-width column with a 24 px margin, not a floating card — a card
/// would imply the screen has somewhere else to go, and it does not. There is
/// no registration, no password reset and no OAuth: accounts are issued by the
/// dinas through a seeder, and the line at the bottom says so rather than
/// leaving someone hunting for a link that was never built.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// The screen gutter: 24 on each side, the largest spacing step.
  static const double margin = FlowSpace.xl;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Read once, in initState: the fields are the user's to edit from here on,
    // and re-applying the demo values on a later rebuild would fight them.
    final prefill = ref.read(prefillDemoCredentialsProvider);
    _email = TextEditingController(text: prefill ? DemoOperator.email : '');
    _password = TextEditingController(
      text: prefill ? DemoOperator.password : '',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // A second tap while the first is in flight would post the credentials
    // twice and can trip a lockout counter on the real server.
    if (_busy) return;

    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Email dan kata sandi harus diisi');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final failure = await ref
        .read(authProvider.notifier)
        .signIn(email: _email.text, password: _password.text);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    // An expired session explains itself here rather than dumping the operator
    // on a blank form wondering what happened.
    final auth = ref.watch(authProvider);
    final message = _error ?? (auth is AuthSignedOut ? auth.message : null);

    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      body: MaxWidth448(
        child: SafeArea(
          // Centred vertically, as the reference sits — and scrollable, so the
          // block rides up instead of being clipped when the keyboard opens.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: LoginScreen.margin,
                vertical: FlowSpace.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 2 * LoginScreen.margin,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FlowSense', style: type.metricLarge),
                    const SizedBox(height: FlowSpace.xs),
                    Text(
                      'Konsol operator',
                      style: type.body.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: FlowSpace.xxl),
                    _Field(
                      key: const ValueKey('field-email'),
                      label: 'Email',
                      hint: 'Masukkan email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: FlowSpace.lg),
                    _Field(
                      key: const ValueKey('field-password'),
                      label: 'Kata sandi',
                      hint: 'Masukkan kata sandi',
                      controller: _password,
                      obscure: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      trailing: IconButton(
                        key: const ValueKey('toggle-password'),
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: FlowIconSize.md,
                          color: colors.textSecondary,
                        ),
                        tooltip: _obscure
                            ? 'Perlihatkan kata sandi'
                            : 'Sembunyikan kata sandi',
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: FlowSpace.lg),
                      _ErrorLine(message: message),
                    ],
                    const SizedBox(height: FlowSpace.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? SizedBox(
                                width: FlowIconSize.sm,
                                height: FlowIconSize.sm,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.surfaceCard,
                                ),
                              )
                            : const Text('Masuk'),
                      ),
                    ),
                    const SizedBox(height: FlowSpace.xl),
                    Text(
                      'Akun diterbitkan oleh dinas. '
                      'Hubungi administrator bila lupa sandi.',
                      textAlign: TextAlign.center,
                      style: type.caption.copyWith(color: colors.textMuted),
                    ),
                    // The way out. Since the console is a mode rather than a
                    // separate install, someone can arrive here by pressing a
                    // button in Langganan without holding an account — and
                    // must not be left on a form they cannot fill in, with no
                    // route back to the map.
                    const SizedBox(height: FlowSpace.sm),
                    Center(
                      child: TextButton(
                        key: const ValueKey('back-to-warga'),
                        // Ink rather than the scheme's seeded blue, like every
                        // other control on this screen.
                        style: TextButton.styleFrom(
                          foregroundColor: colors.textPrimary,
                        ),
                        onPressed: () => ref
                            .read(appModeProvider.notifier)
                            .switchTo(AppMode.warga),
                        child: const Text('Kembali ke tampilan warga'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A label above a bordered field. Flat, hairline border, no shadow.
class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: type.sectionTitle),
        const SizedBox(height: FlowSpace.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(FlowRadius.sm),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  autofillHints: autofillHints,
                  onSubmitted: onSubmitted,
                  style: type.body,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: type.body.copyWith(color: colors.textSecondary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: FlowSpace.md,
                      vertical: FlowSpace.lg,
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

/// One red line above the button.
///
/// Not a snackbar: a snackbar slides away on a timer, and someone reading a
/// password error is looking at the field, not the bottom of the screen.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
    final ink = colors.statusEmergency;

    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: FlowIconSize.sm, color: ink),
          const SizedBox(width: FlowSpace.sm),
          Expanded(
            child: Text(
              message,
              style: type.body.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
