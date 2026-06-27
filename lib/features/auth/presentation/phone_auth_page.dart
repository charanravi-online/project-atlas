import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/atlas_button.dart';

/// Handles both "sign in with phone" and "link phone to existing account".
/// Pass [isLinking] = true when called from Settings to link a phone number.
class PhoneAuthPage extends ConsumerStatefulWidget {
  final bool isLinking;

  const PhoneAuthPage({super.key, this.isLinking = false});

  @override
  ConsumerState<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends ConsumerState<PhoneAuthPage> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    if (widget.isLinking) {
      await ref.read(authProvider.notifier).requestLinkPhoneOtp(phone);
    } else {
      await ref.read(authProvider.notifier).requestPhoneOtp(phone);
    }
  }

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) return;
    if (widget.isLinking) {
      await ref.read(authProvider.notifier).confirmLinkPhoneOtp(code);
      if (mounted) {
        final auth = ref.read(authProvider);
        if (auth.error == null) context.pop();
      }
    } else {
      await ref.read(authProvider.notifier).verifyPhoneOtp(code);
      if (mounted) {
        final auth = ref.read(authProvider);
        if (auth.isAuthenticated && !auth.isGuest) context.go('/feed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final awaitingOtp = authState.awaitingOtp;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (awaitingOtp) {
              // Go back to phone entry — reset verification id.
              ref
                  .read(authProvider.notifier)
                  .requestPhoneOtp('')
                  .ignore();
            }
            context.pop();
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          widget.isLinking ? 'Link Phone Number' : 'Phone Sign-In',
          style: AppTextStyles.headlineMedium,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              if (!awaitingOtp) ...[
                Text(
                  'Enter your phone\nnumber',
                  style: AppTextStyles.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ll send you a one-time verification code.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 36),
                if (authState.error != null) _ErrorBanner(authState.error!),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))],
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: '+1 555 000 1234',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    helperText: 'Include your country code',
                  ),
                  onSubmitted: (_) => _sendOtp(),
                ),
                const SizedBox(height: 32),
                AtlasButton(
                  label: 'Send Code',
                  onPressed: _sendOtp,
                  isLoading: authState.isLoading,
                  width: double.infinity,
                ),
              ] else ...[
                Text(
                  'Enter the code\nwe sent you',
                  style: AppTextStyles.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your SMS for the 6-digit code.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 36),
                if (authState.error != null) _ErrorBanner(authState.error!),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.displayMedium.copyWith(
                    letterSpacing: 12,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '------',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 32),
                AtlasButton(
                  label: 'Verify',
                  onPressed: _verify,
                  isLoading: authState.isLoading,
                  width: double.infinity,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: authState.isLoading ? null : _sendOtp,
                    child: Text(
                      'Resend code',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withAlpha(60)),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
      ),
    );
  }
}
