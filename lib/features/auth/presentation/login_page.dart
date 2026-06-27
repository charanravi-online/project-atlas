import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/atlas_button.dart';
import '../../../core/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await ref
        .read(authProvider.notifier)
        .loginWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) context.go('/feed');
  }

  Future<void> _loginWithGoogle() async {
    await ref.read(authProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              _AtlasLogoSmall(),
              const SizedBox(height: 40),
              Text('Welcome\nback', style: AppTextStyles.displayLarge),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue exploring',
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
                  child: Text(
                    authState.error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error),
                  ),
                ),
              // ── Social sign-in ──────────────────────────────────────────
              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onPressed: authState.isLoading ? null : _loginWithGoogle,
              ),
              const SizedBox(height: 10),
              _SocialButton(
                icon: Icons.phone_rounded,
                label: 'Continue with Phone',
                onPressed: authState.isLoading
                    ? null
                    : () => context.push('/phone-auth'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or sign in with email', style: AppTextStyles.caption),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              // ── Email / password ────────────────────────────────────────
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
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Password',
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Forgot password?',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AtlasButton(
                label: 'Sign In',
                onPressed: _login,
                isLoading: authState.isLoading,
                width: double.infinity,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: authState.isLoading
                      ? null
                      : () async {
                          await ref.read(authProvider.notifier).loginAsGuest();
                          if (context.mounted) context.go('/feed');
                        },
                  child: Text(
                    'Continue as Guest',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ",
                      style: AppTextStyles.bodySmall),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: Text(
                      'Sign up',
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

class _AtlasLogoSmall extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Icon(Icons.explore_rounded,
          color: AppColors.textPrimary, size: 24),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: AppColors.textPrimary),
        label: Text(label,
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.textPrimary)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// Keep for register page compatibility
class AtlasSocialButton extends StatelessWidget {
  final String label;
  final String iconAsset;
  final VoidCallback? onPressed;

  const AtlasSocialButton({
    super.key,
    required this.label,
    required this.iconAsset,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label,
          style: AppTextStyles.labelMedium
              .copyWith(color: AppColors.textPrimary)),
    );
  }
}
