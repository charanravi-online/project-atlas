import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/providers/feed_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/atlas_avatar.dart';
import '../../../core/widgets/atlas_tag.dart';
import '../../../core/widgets/follow_button.dart';

const _searchCategories = ['Maps', 'Pins', 'Creators', 'Cities', 'Tags'];

const _trendingTags = [
  'hidden gems',
  'tokyo',
  'street food',
  'sunrise spots',
  'barcelona',
  'photography',
  'kyoto',
  'off the beaten path',
  'local favorites',
];

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _ctrl = TextEditingController();
  String _selectedTab = 'Maps';
  bool _isSearching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _applyExternalQuery(String q) {
    if (q.isEmpty) return;
    _ctrl.text = q;
    setState(() => _isSearching = true);
    // Consume so it doesn't re-trigger on rebuild.
    Future.microtask(
        () => ref.read(searchQueryProvider.notifier).state = '');
  }

  @override
  Widget build(BuildContext context) {
    // Listen for tag taps from other screens setting the query provider.
    ref.listen<String>(searchQueryProvider, (_, next) => _applyExternalQuery(next));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchBar(
              controller: _ctrl,
              onChanged: (q) => setState(() => _isSearching = q.isNotEmpty),
              onClear: () {
                _ctrl.clear();
                setState(() => _isSearching = false);
              },
            ),
            const SizedBox(height: 4),
            _TabRow(
              selected: _selectedTab,
              onChanged: (t) => setState(() => _selectedTab = t),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isSearching
                  ? _SearchResults(query: _ctrl.text, tab: _selectedTab)
                  : _DiscoverContent(
                      onTagTap: (tag) {
                        _ctrl.text = tag;
                        setState(() => _isSearching = true);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: false,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search maps, places, creators...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textTertiary, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textTertiary, size: 18),
                  onPressed: onClear,
                )
              : null,
        ),
      ),
    );
  }
}

// ── Tab row ────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TabRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _searchCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => AtlasTag(
          label: _searchCategories[i],
          isSelected: selected == _searchCategories[i],
          onTap: () => onChanged(_searchCategories[i]),
        ),
      ),
    );
  }
}

// ── Discover content ───────────────────────────────────────────────────────

class _DiscoverContent extends ConsumerWidget {
  final ValueChanged<String> onTagTap;

  const _DiscoverContent({required this.onTagTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorsAsync = ref.watch(suggestedCreatorsProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Trending Tags', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trendingTags
              .map((t) => AtlasTag(
                    label: '#$t',
                    onTap: () => onTagTap(t),
                  ))
              .toList(),
        ),
        const SizedBox(height: 28),
        Text('Trending Maps', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 14),
        ...MockData.trendingMaps.take(3).map(
              (m) => _MapListTile(
                title: m.title,
                subtitle:
                    '${m.pinCount} pins · ${MockData.formatCount(m.savedCount)} saves',
                imageUrl: m.coverImageUrl,
                categories: m.categories,
              ),
            ),
        const SizedBox(height: 28),
        Text('Creators to Follow', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 14),
        creatorsAsync.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (creators) => Column(
            children: creators
                .map((c) => _CreatorListTile(
                      userId: c.id,
                      name: c.displayName,
                      username: '@${c.username}',
                      avatarUrl: c.avatarUrl,
                      followers: MockData.formatCount(c.followers),
                      isVerified: c.isVerified,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ── Search results ─────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  final String query;
  final String tab;

  const _SearchResults({required this.query, required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storySearchProvider(query));
    final maps = MockData.trendingMaps
        .where((m) =>
            m.title.toLowerCase().contains(query.toLowerCase()) ||
            m.categories
                .any((c) => c.toLowerCase().contains(query.toLowerCase())))
        .toList();

    return storiesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => Center(
        child: Text('Search failed', style: AppTextStyles.bodySmall),
      ),
      data: (stories) {
        if (maps.isEmpty && stories.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off_rounded,
                    size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                Text(
                  'No results for "$query"',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            if (maps.isNotEmpty) ...[
              Text('Maps', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 10),
              ...maps.map((m) => _MapListTile(
                    title: m.title,
                    subtitle: m.creatorName,
                    imageUrl: m.coverImageUrl,
                    categories: m.categories,
                  )),
              const SizedBox(height: 20),
            ],
            if (stories.isNotEmpty) ...[
              Text('Pins', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Sorted by popularity',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 10),
              ...stories.map((s) => _StoryListTile(
                    title: s.title,
                    location: s.locationName ?? '',
                    imageUrl: s.imageUrls.isNotEmpty ? s.imageUrls.first : null,
                    likes: s.likes,
                    saves: s.savedCount,
                    onTap: () => context.push('/pin/${s.id}'),
                  )),
            ],
          ],
        );
      },
    );
  }
}

// ── List tile widgets ──────────────────────────────────────────────────────

class _MapListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final List<String> categories;

  const _MapListTile({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.categories = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Thumb(imageUrl: imageUrl, fallbackIcon: Icons.map_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTextStyles.caption),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    categories.take(3).join(' · '),
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _StoryListTile extends StatelessWidget {
  final String title;
  final String location;
  final String? imageUrl;
  final int likes;
  final int saves;
  final VoidCallback? onTap;

  const _StoryListTile({
    required this.title,
    required this.location,
    this.imageUrl,
    required this.likes,
    required this.saves,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _Thumb(imageUrl: imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (location.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Expanded(
                            child: Text(location,
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded,
                          size: 11, color: AppColors.secondary),
                      const SizedBox(width: 3),
                      Text(MockData.formatCount(likes),
                          style: AppTextStyles.caption),
                      const SizedBox(width: 10),
                      const Icon(Icons.bookmark_rounded,
                          size: 11, color: AppColors.accent),
                      const SizedBox(width: 3),
                      Text(MockData.formatCount(saves),
                          style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _CreatorListTile extends StatelessWidget {
  final String userId;
  final String name;
  final String username;
  final String? avatarUrl;
  final String followers;
  final bool isVerified;

  const _CreatorListTile({
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl,
    required this.followers,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/user/$userId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            AtlasAvatar(
                imageUrl: avatarUrl,
                name: name,
                size: 44,
                isVerified: isVerified),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(username, style: AppTextStyles.caption),
                  const SizedBox(height: 3),
                  Text('$followers followers',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary)),
                ],
              ),
            ),
            FollowButton(targetUserId: userId, compact: true),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? imageUrl;
  final IconData fallbackIcon;

  const _Thumb({this.imageUrl, this.fallbackIcon = Icons.location_on_rounded});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  const ColoredBox(color: AppColors.surfaceElevated),
              errorWidget: (_, _, _) => _fallback(fallbackIcon),
            )
          : _fallback(fallbackIcon),
    );
  }

  Widget _fallback(IconData icon) => Container(
        width: 56,
        height: 56,
        color: AppColors.surfaceElevated,
        child: Icon(icon, color: AppColors.textTertiary, size: 22),
      );
}
