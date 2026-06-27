import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/models/map_model.dart';
import '../../../core/models/story_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/feed_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/atlas_avatar.dart';
import '../../../core/widgets/atlas_button.dart';
import '../../../core/widgets/follow_button.dart';
import 'settings_page.dart';

// ── Public user profile (viewed from outside own profile tab) ─────────────

class UserProfilePage extends ConsumerWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(userId));

    return userAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(child: Text('User not found')),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(backgroundColor: AppColors.background),
            body: const Center(child: Text('User not found')),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: DefaultTabController(
            length: 2,
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    user: user,
                    isGuest: false,
                    isOwnProfile: false,
                    showBackButton: true,
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: AppTextStyles.labelMedium,
                      indicatorColor: AppColors.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: AppColors.border,
                      tabs: const [Tab(text: 'Maps'), Tab(text: 'Pins')],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _MapsGrid(),
                  _StoriesGrid(userId: user.id, isGuest: false),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Own profile page ───────────────────────────────────────────────────────

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user ?? MockData.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                user: user,
                isGuest: authState.isGuest,
                isOwnProfile: true,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTextStyles.labelMedium,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppColors.border,
                  tabs: const [
                    Tab(text: 'Maps'),
                    Tab(text: 'Pins'),
                    Tab(text: 'Saved'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _MapsGrid(),
              _StoriesGrid(userId: user.id, isGuest: authState.isGuest),
              _SavedGrid(userId: user.id, isGuest: authState.isGuest),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final UserModel user;
  final bool isGuest;
  final bool isOwnProfile;
  final bool showBackButton;

  const _ProfileHeader({
    required this.user,
    required this.isGuest,
    this.isOwnProfile = true,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 130,
              decoration: const BoxDecoration(color: AppColors.surfaceHighest),
            ),
            if (showBackButton)
              Positioned(
                top: 44,
                left: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.overlay40,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              Positioned(
                top: 44,
                right: 16,
                child: IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.overlay40,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            Positioned(
              bottom: -40,
              left: 20,
              child: AtlasAvatar(
                imageUrl: user.avatarUrl,
                name: user.displayName,
                size: 80,
                showBorder: true,
                isVerified: user.isVerified,
              ),
            ),
          ],
        ),
        const SizedBox(height: 52),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: AppTextStyles.headlineLarge),
                        Text('@${user.username}', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  if (isGuest)
                    AtlasButton(
                      label: 'Sign Up',
                      onPressed: () => context.go('/register'),
                    )
                  else if (isOwnProfile)
                    AtlasButton.outlined(
                      label: 'Edit Profile',
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppColors.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => EditProfileSheet(user: user),
                      ),
                    )
                  else
                    FollowButton(targetUserId: user.id),
                ],
              ),
              if (user.bio != null) ...[
                const SizedBox(height: 12),
                Text(user.bio!, style: AppTextStyles.bodyMedium),
              ],
              if (user.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(user.location!, style: AppTextStyles.bodySmall),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _StatsRow(user: user),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends ConsumerWidget {
  final UserModel user;

  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(userStoriesProvider(user.id));
    final pinCount = storiesAsync.maybeWhen(
      data: (stories) => stories.length,
      orElse: () => user.storiesCount,
    );
    return Row(
      children: [
        _StatItem(value: MockData.formatCount(user.followers), label: 'Followers'),
        const SizedBox(width: 28),
        _StatItem(value: MockData.formatCount(user.following), label: 'Following'),
        const SizedBox(width: 28),
        _StatItem(value: user.mapsCount.toString(), label: 'Maps'),
        const SizedBox(width: 28),
        _StatItem(value: pinCount.toString(), label: 'Pins'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTextStyles.headlineMedium),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

// ── Maps grid (still uses mock data — maps feature is future work) ──────────

class _MapsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final maps = MockData.trendingMaps;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: maps.length,
      itemBuilder: (context, i) => _GridMapCard(map_: maps[i]),
    );
  }
}

class _GridMapCard extends StatelessWidget {
  final MapModel map_;

  const _GridMapCard({required this.map_});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: map_.coverImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: map_.coverImageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, _) =>
                        const ColoredBox(color: AppColors.surfaceElevated),
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: AppColors.surfaceElevated,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textTertiary,
                          size: 24,
                        ),
                      ),
                    ),
                  )
                : const ColoredBox(color: AppColors.surfaceElevated),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  map_.title,
                  style: AppTextStyles.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text('${map_.pinCount} pins', style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stories grid (real Firestore data) ─────────────────────────────────────

class _StoriesGrid extends ConsumerWidget {
  final String userId;
  final bool isGuest;

  const _StoriesGrid({required this.userId, required this.isGuest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isGuest) {
      return _EmptyState(
        icon: Icons.map_outlined,
        title: 'No stories yet',
        subtitle: 'Sign in to see your pins',
      );
    }
    final storiesAsync = ref.watch(userStoriesProvider(userId));
    return storiesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, _) => _EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load stories',
        subtitle: 'Pull to refresh',
      ),
      data: (stories) {
        if (stories.isEmpty) {
          return _EmptyState(
            icon: Icons.map_outlined,
            title: 'No pins yet',
            subtitle: 'Long-press the map to drop your first pin',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: stories.length,
          itemBuilder: (context, i) => _StoryCard(story: stories[i]),
        );
      },
    );
  }
}

class _StoryCard extends StatelessWidget {
  final StoryModel story;

  const _StoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/pin/${story.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (story.imageUrls.isNotEmpty)
              CachedNetworkImage(
                imageUrl: story.imageUrls.first,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ColoredBox(color: AppColors.surfaceElevated),
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
            if (!story.isPublic)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.overlay60,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                story.title,
                style:
                    AppTextStyles.labelMedium.copyWith(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Saved grid (real Firestore data) ───────────────────────────────────────

class _SavedGrid extends ConsumerWidget {
  final String userId;
  final bool isGuest;

  const _SavedGrid({required this.userId, required this.isGuest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isGuest) {
      return _EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'No saved items',
        subtitle: 'Sign in to see your bookmarks',
      );
    }
    final savedAsync = ref.watch(savedStoriesProvider(userId));
    return savedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load saved items',
        subtitle: 'Pull to refresh',
      ),
      data: (stories) {
        if (stories.isEmpty) {
          return _EmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No saved items yet',
            subtitle: 'Places you bookmark will appear here',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: stories.length,
          itemBuilder: (context, i) => _StoryCard(story: stories[i]),
        );
      },
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.background, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
