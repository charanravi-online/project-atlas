import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/firestore_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/atlas_button.dart';

enum _UsernameStatus { idle, checking, available, taken, invalid }

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final u = value.trim().toLowerCase();
    if (u.isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
    if (!_isValid(u)) {
      setState(() => _usernameStatus = _UsernameStatus.invalid);
      return;
    }
    setState(() => _usernameStatus = _UsernameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final taken = await ref
          .read(firestoreServiceProvider)
          .isUsernameTaken(u);
      if (!mounted) return;
      setState(() => _usernameStatus =
          taken ? _UsernameStatus.taken : _UsernameStatus.available);
    });
  }

  bool _isValid(String u) {
    if (u.isEmpty || u.length > 30) return false;
    if (!RegExp(r'^[a-z0-9][a-z0-9_.]*$').hasMatch(u)) return false;
    if (u.contains('..') || u.endsWith('.')) return false;
    return true;
  }

  Future<void> _register() async {
    await ref.read(authProvider.notifier).register(
          _usernameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
    if (!mounted) return;
    final state = ref.read(authProvider);
    if (state.isAuthenticated) context.go('/feed');
  }

  Widget? _usernameSuffix() {
    switch (_usernameStatus) {
      case _UsernameStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _UsernameStatus.available:
        return const Icon(Icons.check_circle_rounded,
            color: AppColors.accent, size: 20);
      case _UsernameStatus.taken:
        return const Icon(Icons.cancel_rounded,
            color: AppColors.secondary, size: 20);
      case _UsernameStatus.invalid:
        return const Icon(Icons.info_outline_rounded,
            color: AppColors.textTertiary, size: 20);
      case _UsernameStatus.idle:
        return null;
    }
  }

  String? _usernameHint() {
    switch (_usernameStatus) {
      case _UsernameStatus.taken:
        return 'Username already taken';
      case _UsernameStatus.invalid:
        return 'Letters, numbers, _ and . only (1–30 chars)';
      case _UsernameStatus.available:
        return 'Available';
      default:
        return null;
    }
  }

  Color _usernameHintColor() {
    switch (_usernameStatus) {
      case _UsernameStatus.taken:
        return AppColors.secondary;
      case _UsernameStatus.available:
        return AppColors.accent;
      default:
        return AppColors.textTertiary;
    }
  }

  bool get _canSubmit =>
      _usernameStatus == _UsernameStatus.available ||
      _usernameStatus == _UsernameStatus.idle;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final hint = _usernameHint();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              IconButton(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                ),
              ),
              const SizedBox(height: 32),
              Text('Join\nAtlas', style: AppTextStyles.displayLarge),
              const SizedBox(height: 8),
              Text(
                'Start mapping your world',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              if (authState.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withAlpha(60)),
                  ),
                  child: Text(authState.error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error)),
                ),
              TextField(
                controller: _usernameCtrl,
                style: AppTextStyles.bodyMedium,
                onChanged: _onUsernameChanged,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'Username',
                  prefixIcon: const Icon(Icons.alternate_email,
                      color: AppColors.textTertiary, size: 20),
                  suffixIcon: _usernameSuffix(),
                  helperText: hint,
                  helperStyle: AppTextStyles.caption.copyWith(
                    color: _usernameHintColor(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined,
                      color: AppColors.textTertiary, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: AppTextStyles.bodyMedium,
                onSubmitted: (_) => _canSubmit ? _register() : null,
                decoration: InputDecoration(
                  hintText: 'Password (min. 8 characters)',
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppColors.textTertiary, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              AtlasButton(
                label: 'Create Account',
                onPressed: _canSubmit ? _register : null,
                isLoading: authState.isLoading,
                width: double.infinity,
              ),
              const SizedBox(height: 20),
              Text(
                'By creating an account you agree to our Terms of Service and Privacy Policy.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ',
                      style: AppTextStyles.bodySmall),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text(
                      'Sign in',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
