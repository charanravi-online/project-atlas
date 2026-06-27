import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/mock/mock_data.dart';
import '../../../../core/models/story_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/interaction_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/atlas_avatar.dart';

class StoryCard extends ConsumerWidget {
  final StoryModel story;
  final VoidCallback? onTap;

  const StoryCard({super.key, required this.story, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interaction = ref.watch(interactionProvider);
    final userId = ref.watch(authProvider.select((s) => s.user?.id));

    final liked = interaction.isLiked(story.id);
    final bookmarked = interaction.isBookmarked(story.id);
    final likesCount = interaction.likeCount(story.id, story.likes);
    final savedCount = interaction.saveCount(story.id, story.savedCount);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StoryImage(story: story),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CreatorRow(story: story),
                  const SizedBox(height: 10),
                  Text(
                    story.title,
                    style: AppTextStyles.headlineMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (story.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      story.description!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _ActionRow(
                    story: story,
                    userId: userId,
                    liked: liked,
                    bookmarked: bookmarked,
                    likesCount: likesCount,
                    savedCount: savedCount,
                    onLikeTap: userId == null
                        ? null
                        : () => ref
                            .read(interactionProvider.notifier)
                            .toggleLike(userId, story.id, story.likes),
                    onBookmarkTap: userId == null
                        ? null
                        : () => ref
                            .read(interactionProvider.notifier)
                            .toggleBookmark(userId, story.id, story.savedCount),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryImage extends StatelessWidget {
  final StoryModel story;

  const _StoryImage({required this.story});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: story.imageUrls.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: story.imageUrls.first,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppColors.surfaceElevated),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: AppColors.surfaceElevated,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.textTertiary,
                        size: 28,
                      ),
                    ),
                  ),
                )
              : const ColoredBox(color: AppColors.surfaceElevated),
        ),
        Positioned.fill(
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 1.0],
                colors: [Colors.transparent, AppColors.overlay60],
              ),
            ),
          ),
        ),
        if (story.locationName != null)
          Positioned(
            bottom: 12,
            left: 12,
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  story.locationName!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        if (story.imageUrls.length > 1)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.overlay60,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${story.imageUrls.length}',
                    style:
                        AppTextStyles.caption.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CreatorRow extends StatelessWidget {
  final StoryModel story;

  const _CreatorRow({required this.story});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/user/${story.creatorId}'),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AtlasAvatar(
            imageUrl: story.creatorAvatar,
            name: story.creatorName,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(story.creatorName, style: AppTextStyles.labelMedium),
          const SizedBox(width: 6),
          const Text('·', style: TextStyle(color: AppColors.textTertiary)),
          const SizedBox(width: 6),
          Text(MockData.timeAgo(story.createdAt), style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final StoryModel story;
  final String? userId;
  final bool liked;
  final bool bookmarked;
  final int likesCount;
  final int savedCount;
  final VoidCallback? onLikeTap;
  final VoidCallback? onBookmarkTap;

  const _ActionRow({
    required this.story,
    required this.userId,
    required this.liked,
    required this.bookmarked,
    required this.likesCount,
    required this.savedCount,
    this.onLikeTap,
    this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionBtn(
          icon: liked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: MockData.formatCount(likesCount),
          active: liked,
          activeColor: AppColors.secondary,
          onTap: onLikeTap,
        ),
        const SizedBox(width: 18),
        _ActionBtn(
          icon: Icons.chat_bubble_outline_rounded,
          label: '${story.commentsCount}',
        ),
        const SizedBox(width: 18),
        _ActionBtn(
          icon: bookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: MockData.formatCount(savedCount),
          active: bookmarked,
          activeColor: AppColors.accent,
          onTap: onBookmarkTap,
        ),
        const Spacer(),
        _ActionBtn(icon: Icons.ios_share_rounded, label: 'Share'),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.activeColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
