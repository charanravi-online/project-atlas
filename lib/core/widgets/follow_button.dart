import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/follow_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A Follow / Following toggle button. Shows nothing for guests or own profile.
class FollowButton extends ConsumerStatefulWidget {
  final String targetUserId;
  final bool compact;

  const FollowButton({super.key, required this.targetUserId, this.compact = false});

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  @override
  void initState() {
    super.initState();
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId != null && currentUserId != widget.targetUserId) {
      Future.microtask(() => ref
          .read(followProvider.notifier)
          .ensureLoaded(currentUserId, widget.targetUserId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider.select((s) => s.user?.id));
    if (currentUserId == null || currentUserId == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final followState = ref.watch(followProvider);
    final isLoaded = followState.isLoaded(widget.targetUserId);
    final isFollowing = followState.isFollowing(widget.targetUserId);

    Future<void> onToggle() async {
      await ref
          .read(followProvider.notifier)
          .toggle(currentUserId, widget.targetUserId);
      ref.invalidate(userProfileProvider(widget.targetUserId));
      ref.read(authProvider.notifier).refreshUser();
    }

    if (!isLoaded) {
      return _btn(
        label: 'Follow',
        filled: true,
        onPressed: null,
        compact: widget.compact,
      );
    }

    return _btn(
      label: isFollowing ? 'Following' : 'Follow',
      filled: !isFollowing,
      onPressed: onToggle,
      compact: widget.compact,
    );
  }

  Widget _btn({
    required String label,
    required bool filled,
    required VoidCallback? onPressed,
    required bool compact,
  }) {
    final vPad = compact ? 6.0 : 8.0;
    final hPad = compact ? 14.0 : 20.0;

    if (filled) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primary.withAlpha(20),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label,
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: AppTextStyles.labelMedium
              .copyWith(color: AppColors.textSecondary)),
    );
  }
}
