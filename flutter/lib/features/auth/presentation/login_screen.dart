import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../data/auth_repository.dart';

/// Экран входа. Логика (POST /api/login → сохранить сессию → Dashboard)
/// не меняется, переработан только внешний вид.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _authRepo = AuthRepository();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    final phone = _phone.text.trim();
    final password = _password.text.trim();
    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = 'Укажите телефон и пароль');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _authRepo.login(phone: phone, password: password);
      await SessionStore.instance.save(response);
      if (mounted) context.go('/dashboard');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось войти. Попробуйте позже.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const _AuroraBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xxxl, AppSpacing.xl, AppSpacing.xl),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 52),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LogoMark(color: c.accent),
                            const SizedBox(height: AppSpacing.xl),
                            Text('SMART24',
                                style: text.displaySmall?.copyWith(
                                  color: c.textPrimary,
                                  letterSpacing: 1,
                                )),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Управляйте автоматами и выручкой\nв одном приложении',
                              style: text.bodyLarge?.copyWith(
                                color: c.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 90),
                        child: AppCard(
                          elevated: true,
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Вход в кабинет',
                                  style: text.titleMedium
                                      ?.copyWith(color: c.textPrimary)),
                              const SizedBox(height: AppSpacing.xl),
                              TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                autocorrect: false,
                                enabled: !_loading,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Телефон',
                                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextField(
                                controller: _password,
                                obscureText: _obscure,
                                autocorrect: false,
                                enableSuggestions: false,
                                enabled: !_loading,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Пароль',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(_obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined),
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: AppDuration.base,
                                curve: Curves.easeOut,
                                child: _error == null
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                            top: AppSpacing.md),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline_rounded,
                                                size: 16, color: c.danger),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(_error!,
                                                  style: text.bodySmall
                                                      ?.copyWith(
                                                          color: c.danger)),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: AnimatedSwitcher(
                                  duration: AppDuration.base,
                                  child: _loading
                                      ? const SizedBox(
                                          key: ValueKey('l'),
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white),
                                        )
                                      : Row(
                                          key: const ValueKey('t'),
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Text('Войти'),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded,
                                                size: 18),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Center(
                        child: Text(
                          'Smart24 · сеть вендинговых автоматов',
                          style: text.bodySmall?.copyWith(color: c.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: AppRadius.rLg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, context.colors.accentAlt],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
    );
  }
}

/// Мягкий фон: несколько размытых цветовых пятен. Без картинок.
class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Positioned.fill(
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -90,
              child: _blob(240, c.accent.withValues(alpha: c.isDark ? 0.28 : 0.20)),
            ),
            Positioned(
              top: 120,
              left: -110,
              child: _blob(
                  220, c.accentAlt.withValues(alpha: c.isDark ? 0.22 : 0.16)),
            ),
            Positioned(
              bottom: -140,
              right: -60,
              child: _blob(
                  260, AppColors.cyan.withValues(alpha: c.isDark ? 0.16 : 0.12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 60)],
      ),
    );
  }
}
