import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/story_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/feed_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/atlas_tag.dart';
import 'widgets/story_card.dart';

const _categories = [
  'All',
  'Food',
  'Travel',
  'Photography',
  'Nature',
  'Coffee',
  'Architecture',
  'Nightlife',
  'Hiking',
  'Culture',
];

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: AppColors.background,
            toolbarHeight: 64,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user != null
                              ? 'Hey, ${user.displayName.split(' ').first}'
                              : 'Explore Atlas',
                          style: AppTextStyles.headlineMedium,
                        ),
                        Text(
                          'Discover extraordinary places',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTextStyles.labelMedium,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppColors.border,
              tabs: const [
                Tab(text: 'Following'),
                Tab(text: 'Trending'),
                Tab(text: 'Nearby'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _FeedTab(
              selectedCategory: _selectedCategory,
              onCategoryChanged: (c) => setState(() => _selectedCategory = c),
            ),
            _FeedTab(
              selectedCategory: _selectedCategory,
              onCategoryChanged: (c) => setState(() => _selectedCategory = c),
            ),
            _FeedTab(
              selectedCategory: _selectedCategory,
              onCategoryChanged: (c) => setState(() => _selectedCategory = c),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const _FeedTab({
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(nearbyStoriesProvider);
    final userLocation = ref.watch(userLocationProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _CategoryScroll(
                selected: selectedCategory,
                onChanged: onCategoryChanged,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Popular Pins Near You',
                      style: AppTextStyles.headlineMedium,
                    ),
                    if (userLocation != null) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.my_location_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        storiesAsync.when(
          loading: () => SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ShimmerCard(),
              ),
              childCount: 3,
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Center(
              child: Text(
                'Failed to load pins',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ),
          data: (stories) {
            // Filter by category
            var filtered = selectedCategory == 'All'
                ? [...stories]
                : stories.where((s) {
                    return s.tags.any((t) =>
                            t.toLowerCase() ==
                            selectedCategory.toLowerCase()) ||
                        s.title
                            .toLowerCase()
                            .contains(selectedCategory.toLowerCase()) ||
                        (s.locationName?.toLowerCase().contains(
                                selectedCategory.toLowerCase()) ==
                            true);
                  }).toList();

            // Sort by popularity weighted by proximity
            filtered.sort((a, b) {
              final scoreA = _pinScore(a, userLocation);
              final scoreB = _pinScore(b, userLocation);
              return scoreB.compareTo(scoreA);
            });

            if (filtered.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Text(
                      'No pins match "$selectedCategory" yet.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: StoryCard(
                    story: filtered[i],
                    onTap: () => context.push('/pin/${filtered[i].id}'),
                  ),
                ),
                childCount: filtered.length,
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  // Popularity score decayed by distance: closer + more liked pins rank higher.
  // decay = 1 / (1 + distance_km / 10) so a pin 10 km away is weighted at 50%.
  double _pinScore(StoryModel story, dynamic position) {
    final popularity = (story.likes + story.savedCount * 2).toDouble();
    if (position == null) return popularity;
    final distKm = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          story.latitude,
          story.longitude,
        ) /
        1000;
    return popularity * (1 / (1 + distKm / 10));
  }
}

class _CategoryScroll extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategoryScroll({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => AtlasTag(
          label: _categories[i],
          isSelected: selected == _categories[i],
          onTap: () => onChanged(_categories[i]),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.surfaceHighest,
      child: Container(
        height: 260,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
