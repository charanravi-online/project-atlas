import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/models/story_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/feed_provider.dart';
import '../../../core/providers/firestore_provider.dart';
import '../../../core/providers/interaction_provider.dart';
import '../../../core/widgets/follow_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/atlas_avatar.dart';
import '../../../core/widgets/atlas_tag.dart';

class PinDetailPage extends ConsumerWidget {
  final String storyId;

  const PinDetailPage({super.key, required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyAsync = ref.watch(storyByIdProvider(storyId));
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;

    return storyAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(child: Text('Story not found')),
      ),
      data: (story) {
        if (story == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(backgroundColor: AppColors.background),
            body: const Center(child: Text('Story not found')),
          );
        }
        return _StoryDetailView(
          story: story,
          isOwner: currentUserId != null && currentUserId == story.creatorId,
          userId: currentUserId,
        );
      },
    );
  }
}

class _StoryDetailView extends ConsumerStatefulWidget {
  final StoryModel story;
  final bool isOwner;
  final String? userId;

  const _StoryDetailView({
    required this.story,
    required this.isOwner,
    this.userId,
  });

  @override
  ConsumerState<_StoryDetailView> createState() => _StoryDetailViewState();
}

class _StoryDetailViewState extends ConsumerState<_StoryDetailView> {
  Future<void> _deletePin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete pin?', style: AppTextStyles.headlineMedium),
        content: Text(
          'This cannot be undone.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AppTextStyles.labelMedium.copyWith(color: AppColors.secondary)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(firestoreServiceProvider).deleteStory(widget.story.id, widget.story.creatorId);
    if (!mounted) return;
    ref.invalidate(nearbyStoriesProvider);
    ref.invalidate(userStoriesProvider(widget.story.creatorId));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _StoryAppBar(story: story, isOwner: widget.isOwner, onDelete: _deletePin),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CreatorRow(story: story, isOwner: widget.isOwner),
                  const SizedBox(height: 16),
                  Text(story.title, style: AppTextStyles.displayMedium),
                  if (story.locationName != null) ...[
                    const SizedBox(height: 8),
                    _LocationChip(name: story.locationName!),
                  ],
                  const SizedBox(height: 16),
                  _ActionBar(story: story, userId: widget.userId),
                  const Divider(height: 32),
                  if (story.description != null) ...[
                    Text(story.description!, style: AppTextStyles.bodyLarge),
                    const SizedBox(height: 24),
                  ],
                  if (story.imageUrls.length > 1) ...[
                    Text('Photos', style: AppTextStyles.headlineMedium),
                    const SizedBox(height: 12),
                    _PhotosGrid(urls: story.imageUrls),
                    const SizedBox(height: 24),
                  ],
                  if (story.bestTime != null) ...[
                    _InfoCard(
                      icon: Icons.access_time_rounded,
                      title: 'Best Time to Visit',
                      body: story.bestTime!,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (story.tips != null) ...[
                    _InfoCard(
                      icon: Icons.lightbulb_outline_rounded,
                      title: 'Tips',
                      body: story.tips!,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (story.warnings != null) ...[
                    _InfoCard(
                      icon: Icons.warning_amber_rounded,
                      title: 'Heads Up',
                      body: story.warnings!,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (story.tags.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text('Tags', style: AppTextStyles.headlineMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: story.tags
                          .map((t) => AtlasTag(
                                label: t,
                                onTap: () {
                                  ref.read(searchQueryProvider.notifier).state = t;
                                  context.go('/search');
                                },
                              ))
                          .toList(),
                    ),
                  ],
                  const Divider(height: 40),
                  _CommentsSection(storyId: story.id, userId: widget.userId),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────

class _StoryAppBar extends StatelessWidget {
  final StoryModel story;
  final bool isOwner;
  final VoidCallback? onDelete;

  const _StoryAppBar({required this.story, required this.isOwner, this.onDelete});

  void _share() {
    Share.share(
      '📍 ${story.title}\n'
      '${story.description != null ? "${story.description!}\n\n" : ""}'
      'Open in Maps: https://maps.google.com/?q=${story.latitude},${story.longitude}',
      subject: story.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.overlay60,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
      ),
      actions: [
        if (isOwner) ...[
          Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.overlay60,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _EditPinSheet(story: story),
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.overlay60,
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: _share,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.overlay60,
              ),
              child: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: story.imageUrls.isNotEmpty
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
                      size: 32,
                    ),
                  ),
                ),
              )
            : const ColoredBox(color: AppColors.surfaceElevated),
      ),
    );
  }
}

// ── Edit sheet ─────────────────────────────────────────────────────────────

class _EditPinSheet extends ConsumerStatefulWidget {
  final StoryModel story;

  const _EditPinSheet({required this.story});

  @override
  ConsumerState<_EditPinSheet> createState() => _EditPinSheetState();
}

class _EditPinSheetState extends ConsumerState<_EditPinSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late bool _isPublic;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.story.title);
    _descCtrl = TextEditingController(text: widget.story.description ?? '');
    _isPublic = widget.story.isPublic;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(firestoreServiceProvider);
      final updated = StoryModel(
        id: widget.story.id,
        title: title,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        mapId: widget.story.mapId,
        creatorId: widget.story.creatorId,
        creatorName: widget.story.creatorName,
        creatorAvatar: widget.story.creatorAvatar,
        latitude: widget.story.latitude,
        longitude: widget.story.longitude,
        locationName: widget.story.locationName,
        imageUrls: widget.story.imageUrls,
        tags: widget.story.tags,
        bestTime: widget.story.bestTime,
        tips: widget.story.tips,
        warnings: widget.story.warnings,
        likes: widget.story.likes,
        commentsCount: widget.story.commentsCount,
        savedCount: widget.story.savedCount,
        isPublic: _isPublic,
        createdAt: widget.story.createdAt,
      );
      await service.updateStory(updated);
      if (!mounted) return;
      ref.invalidate(storyByIdProvider(widget.story.id));
      ref.invalidate(nearbyStoriesProvider);
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
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
              Text('Edit pin', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 20),
              TextField(
                controller: _titleCtrl,
                style: AppTextStyles.bodyLarge,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descCtrl,
                style: AppTextStyles.bodyLarge,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                title: Text('Public', style: AppTextStyles.bodyMedium),
                subtitle: Text(
                  'Visible to everyone',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                activeThumbColor: AppColors.accent,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
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
      ),
    );
  }
}

// ── Supporting widgets ──────────────────────────────────────────────────────

class _CreatorRow extends StatelessWidget {
  final StoryModel story;
  final bool isOwner;

  const _CreatorRow({required this.story, this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.push('/user/${story.creatorId}'),
          child: Row(
            children: [
              AtlasAvatar(
                imageUrl: story.creatorAvatar,
                name: story.creatorName,
                size: 36,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(story.creatorName, style: AppTextStyles.labelLarge),
                  Text(MockData.timeAgo(story.createdAt),
                      style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        if (!isOwner) FollowButton(targetUserId: story.creatorId, compact: true),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  final String name;

  const _LocationChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            name,
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Action bar ─────────────────────────────────────────────────────────────

class _ActionBar extends ConsumerStatefulWidget {
  final StoryModel story;
  final String? userId;

  const _ActionBar({required this.story, this.userId});

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _likeLoading = false;
  bool _bookmarkLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) _loadInteractionState();
  }

  Future<void> _loadInteractionState() async {
    await Future.wait([
      ref
          .read(interactionProvider.notifier)
          .ensureLikeLoaded(widget.userId!, widget.story.id),
      ref
          .read(interactionProvider.notifier)
          .ensureBookmarkLoaded(widget.userId!, widget.story.id),
    ]);
  }

  Future<void> _toggleLike() async {
    if (widget.userId == null || _likeLoading) return;
    setState(() => _likeLoading = true);
    try {
      await ref.read(interactionProvider.notifier).toggleLike(
            widget.userId!,
            widget.story.id,
            widget.story.likes,
          );
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _toggleBookmark() async {
    if (widget.userId == null || _bookmarkLoading) return;
    setState(() => _bookmarkLoading = true);
    try {
      await ref.read(interactionProvider.notifier).toggleBookmark(
            widget.userId!,
            widget.story.id,
            widget.story.savedCount,
          );
      ref.invalidate(savedStoriesProvider(widget.userId!));
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  Future<void> _navigate() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.story.latitude},${widget.story.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _share() async {
    await Share.share(
      '📍 ${widget.story.title}\n'
      '${widget.story.description != null ? "${widget.story.description!}\n\n" : ""}'
      'Open in Maps: https://maps.google.com/?q=${widget.story.latitude},${widget.story.longitude}',
      subject: widget.story.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final interaction = ref.watch(interactionProvider);
    final liked = interaction.isLiked(widget.story.id);
    final bookmarked = interaction.isBookmarked(widget.story.id);
    final likesCount = interaction.likeCount(widget.story.id, widget.story.likes);
    final savedCount =
        interaction.saveCount(widget.story.id, widget.story.savedCount);

    return Row(
      children: [
        _ActionBtn(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: MockData.formatCount(likesCount),
          active: liked,
          color: AppColors.secondary,
          onTap: _likeLoading ? null : _toggleLike,
        ),
        const SizedBox(width: 20),
        _ActionBtn(
          icon: Icons.chat_bubble_outline_rounded,
          label: '${widget.story.commentsCount}',
          onTap: () {},
        ),
        const SizedBox(width: 20),
        _ActionBtn(
          icon: bookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: MockData.formatCount(savedCount),
          active: bookmarked,
          color: AppColors.accent,
          onTap: _bookmarkLoading ? null : _toggleBookmark,
        ),
        const Spacer(),
        _ActionBtn(
          icon: Icons.navigation_rounded,
          label: 'Navigate',
          onTap: _navigate,
        ),
        const SizedBox(width: 16),
        _ActionBtn(
          icon: Icons.ios_share_rounded,
          label: 'Share',
          onTap: _share,
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: active ? color : AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: active ? color : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotosGrid extends StatelessWidget {
  final List<String> urls;

  const _PhotosGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: urls.length,
      itemBuilder: (context, i) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: urls[i],
          fit: BoxFit.cover,
          placeholder: (_, _) =>
              const ColoredBox(color: AppColors.surfaceElevated),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(body, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comments ───────────────────────────────────────────────────────────────

class _CommentsSection extends ConsumerStatefulWidget {
  final String storyId;
  final String? userId;

  const _CommentsSection({required this.storyId, this.userId});

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      final comment = CommentModel(
        id: const Uuid().v4(),
        userId: user.id,
        userName: user.displayName,
        userAvatar: user.avatarUrl,
        text: text,
        createdAt: DateTime.now(),
      );
      await ref
          .read(firestoreServiceProvider)
          .addComment(widget.storyId, comment);
      _ctrl.clear();
      ref.invalidate(commentsProvider(widget.storyId));
      ref.invalidate(storyByIdProvider(widget.storyId));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.storyId));
    final isGuest = ref.watch(authProvider.select((s) => s.isGuest));
    final hasUser = widget.userId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 16),
        commentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Could not load comments.',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          data: (comments) => comments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Be the first to comment!',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                )
              : Column(
                  children: comments
                      .map((c) => _CommentTile(comment: c))
                      .toList(),
                ),
        ),
        if (isGuest)
          Text(
            'Sign in to leave a comment.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          )
        else if (hasUser)
          _buildInput(),
      ],
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textTertiary),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : GestureDetector(
                  onTap: _send,
                  child: const Icon(Icons.send_rounded,
                      color: AppColors.primary, size: 20),
                ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AtlasAvatar(
            imageUrl: comment.userAvatar,
            name: comment.userName,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.userName, style: AppTextStyles.labelMedium),
                    const SizedBox(width: 8),
                    Text(
                      MockData.timeAgo(comment.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.text, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
