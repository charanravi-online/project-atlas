import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/firestore_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum _UsernameStatus { idle, checking, available, taken, invalid, unchanged }

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    final providerIds =
        fbUser?.providerData.map((p) => p.providerId).toSet() ?? {};

    final hasEmail = providerIds.contains('password');
    final hasPhone = providerIds.contains('phone');
    final hasGoogle = providerIds.contains('google.com');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
        ),
        title: Text('Settings', style: AppTextStyles.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (user != null) ...[
            _SectionHeader('Account'),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Edit Profile',
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => EditProfileSheet(user: user),
              ),
            ),
            _SectionHeader('Sign-in methods'),
            if (hasGoogle)
              _SettingsTile(
                icon: Icons.g_mobiledata_rounded,
                title: 'Google',
                subtitle: fbUser?.providerData
                    .where((p) => p.providerId == 'google.com')
                    .firstOrNull
                    ?.email,
                trailing: _LinkedBadge(),
              ),
            if (hasEmail)
              _SettingsTile(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: fbUser?.email,
                trailing: _LinkedBadge(),
              )
            else
              _SettingsTile(
                icon: Icons.email_outlined,
                title: 'Add Email',
                subtitle: 'Link an email and password',
                onTap: () => _showLinkEmailSheet(context, ref),
              ),
            if (hasPhone)
              _SettingsTile(
                icon: Icons.phone_outlined,
                title: 'Phone',
                subtitle: fbUser?.phoneNumber,
                trailing: _LinkedBadge(),
              )
            else
              _SettingsTile(
                icon: Icons.phone_outlined,
                title: 'Add Phone',
                subtitle: 'Link a phone number',
                onTap: () => context.push('/phone-auth', extra: true),
              ),
          ],
          _SectionHeader('About'),
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: '1.0.0',
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary.withAlpha(30),
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Sign Out',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.secondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showLinkEmailSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LinkEmailSheet(),
    );
  }
}

class _LinkedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Linked',
        style: AppTextStyles.caption.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _LinkEmailSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LinkEmailSheet> createState() => _LinkEmailSheetState();
}

class _LinkEmailSheetState extends ConsumerState<_LinkEmailSheet> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    await ref
        .read(authProvider.notifier)
        .linkEmailPassword(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    if (ref.read(authProvider).error == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Add Email', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Link an email and password to your account.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            if (authState.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: Text(
                  authState.error!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.error),
                ),
              ),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined,
                    color: AppColors.textTertiary, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Password (min. 8 characters)',
                prefixIcon: const Icon(Icons.lock_outline,
                    color: AppColors.textTertiary, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _link,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary),
                      )
                    : Text('Link Email', style: AppTextStyles.labelLarge),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary)
              : null),
    );
  }
}

// ── Edit profile sheet (public — reused from profile page) ─────────────────

class EditProfileSheet extends ConsumerStatefulWidget {
  final UserModel user;

  const EditProfileSheet({super.key, required this.user});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _websiteCtrl;
  _UsernameStatus _usernameStatus = _UsernameStatus.unchanged;
  Timer? _debounce;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
    _locationCtrl = TextEditingController(text: widget.user.location ?? '');
    _websiteCtrl = TextEditingController(text: widget.user.website ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final u = value.trim().toLowerCase();
    if (u == widget.user.username) {
      setState(() => _usernameStatus = _UsernameStatus.unchanged);
      return;
    }
    if (u.isEmpty || !_isValidUsername(u)) {
      setState(() => _usernameStatus = u.isEmpty ? _UsernameStatus.unchanged : _UsernameStatus.invalid);
      return;
    }
    setState(() => _usernameStatus = _UsernameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final taken = await ref
          .read(firestoreServiceProvider)
          .isUsernameTaken(u, excludeUserId: widget.user.id);
      if (!mounted) return;
      setState(() => _usernameStatus =
          taken ? _UsernameStatus.taken : _UsernameStatus.available);
    });
  }

  bool _isValidUsername(String u) {
    if (u.isEmpty || u.length > 30) return false;
    if (!RegExp(r'^[a-z0-9][a-z0-9_.]*$').hasMatch(u)) return false;
    if (u.contains('..') || u.endsWith('.')) return false;
    return true;
  }

  Widget? _usernameSuffix() {
    switch (_usernameStatus) {
      case _UsernameStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        );
      case _UsernameStatus.available:
        return const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20);
      case _UsernameStatus.taken:
        return const Icon(Icons.cancel_rounded, color: AppColors.secondary, size: 20);
      case _UsernameStatus.invalid:
        return const Icon(Icons.info_outline_rounded, color: AppColors.textTertiary, size: 20);
      case _UsernameStatus.unchanged:
      case _UsernameStatus.idle:
        return null;
    }
  }

  String? _usernameHelper() {
    switch (_usernameStatus) {
      case _UsernameStatus.taken:    return 'Username already taken';
      case _UsernameStatus.invalid:  return 'Letters, numbers, _ and . only (1–30 chars)';
      case _UsernameStatus.available: return 'Available';
      default: return null;
    }
  }

  Color _usernameHelperColor() {
    switch (_usernameStatus) {
      case _UsernameStatus.taken:     return AppColors.secondary;
      case _UsernameStatus.available: return AppColors.accent;
      default: return AppColors.textTertiary;
    }
  }

  bool get _canSave =>
      _usernameStatus != _UsernameStatus.taken &&
      _usernameStatus != _UsernameStatus.invalid &&
      _usernameStatus != _UsernameStatus.checking;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final newUsername = _usernameCtrl.text.trim().toLowerCase();
    if (!_isValidUsername(newUsername) && newUsername != widget.user.username) return;
    setState(() => _saving = true);
    try {
      final updated = UserModel(
        id: widget.user.id,
        username: newUsername,
        displayName: name,
        avatarUrl: widget.user.avatarUrl,
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        followers: widget.user.followers,
        following: widget.user.following,
        mapsCount: widget.user.mapsCount,
        storiesCount: widget.user.storiesCount,
        isVerified: widget.user.isVerified,
      );
      await ref.read(firestoreServiceProvider).insertUser(updated);
      await ref.read(authProvider.notifier).refreshUser();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final helper = _usernameHelper();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Edit Profile', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameCtrl,
              style: AppTextStyles.bodyLarge,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: _onUsernameChanged,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                prefixStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                suffixIcon: _usernameSuffix(),
                helperText: helper,
                helperStyle: AppTextStyles.caption.copyWith(color: _usernameHelperColor()),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bioCtrl,
              style: AppTextStyles.bodyLarge,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _locationCtrl,
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(
                  labelText: 'Location', hintText: 'e.g. Tokyo, Japan'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _websiteCtrl,
              style: AppTextStyles.bodyLarge,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: 'Website', hintText: 'https://'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_saving || !_canSave) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : Text('Save changes', style: AppTextStyles.labelLarge),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
