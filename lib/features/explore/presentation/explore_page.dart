import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/models/story_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/feed_provider.dart';
import '../../../core/providers/firestore_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/atlas_avatar.dart';
import '../../../core/widgets/atlas_tag.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

enum _ExploreSortOption { popular, latest, nearby }

const _exploreCategories = [
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

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  StoryModel? _selectedStory;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  _ExploreSortOption _sortOption = _ExploreSortOption.popular;
  Position? _currentPosition;
  bool _locating = false;
  double _currentZoom = 13.0;
  bool _mapReady = false;

  // Normalizes zoom to [0,1] for sizing: 0 at zoom 10, 1 at zoom 16+
  double get _zoomNorm => ((_currentZoom - 10) / 6).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    // Use cached location immediately if available
    final saved = ref.read(userLocationProvider);
    if (saved != null) _currentPosition = saved;
    _initLocationSilently();
  }

  Future<void> _initLocationSilently() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _currentPosition = position);
      ref.read(userLocationProvider.notifier).state = position;
      if (_mapReady) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _currentZoom,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _currentPosition = position);
      ref.read(userLocationProvider.notifier).state = position;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        14.0,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id ?? MockData.currentUser.id;
    final storiesAsync = ref.watch(exploreStoriesProvider(currentUserId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition != null
                    ? LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      )
                    : const LatLng(20.0, 0.0),
                initialZoom: 13.0,
                minZoom: 4,
                maxZoom: 18,
                onMapReady: () {
                  _mapReady = true;
                  if (_currentPosition != null) {
                    _mapController.move(
                      LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      13.0,
                    );
                  }
                },
                onPositionChanged: (camera, hasGesture) {
                  if (mounted &&
                      (_currentZoom - camera.zoom).abs() >= 0.5) {
                    setState(() => _currentZoom = camera.zoom);
                  }
                },
                onLongPress: (_, point) => _handleMapLongPress(point),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.atlas.app',
                  tileProvider: NetworkTileProvider(silenceExceptions: true),
                  errorTileCallback: (_, _, _) {},
                  errorImage: MemoryImage(
                    Uint8List.fromList(List<int>.filled(1, 0)),
                  ),
                ),
                storiesAsync.when(
                  loading: () => const MarkerLayer(markers: []),
                  error: (_, _) => const MarkerLayer(markers: []),
                  data: (stories) {
                    final filteredStories = _filterStories(
                      stories,
                      currentUserId,
                    );
                    return MarkerLayer(
                      markers: filteredStories
                          .map((s) => _buildMarker(s, currentUserId))
                          .toList(),
                    );
                  },
                ),
                if (_currentPosition != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        radius: 18,
                        color: AppColors.primary.withAlpha(40),
                        borderStrokeWidth: 0,
                        useRadiusInMeter: false,
                      ),
                      CircleMarker(
                        point: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        radius: 8,
                        color: AppColors.primary.withAlpha(220),
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                        useRadiusInMeter: false,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildCategoryChips(),
                  const SizedBox(height: 12),
                  _buildSortRow(storiesAsync, currentUserId),
                ],
              ),
            ),
          ),
          // Locate me button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _locating ? null : _goToCurrentLocation,
              backgroundColor: AppColors.surface,
              elevation: 4,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _currentPosition != null
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      color: _currentPosition != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 20,
                    ),
            ),
          ),
          if (_selectedStory != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _StoryPreviewSheet(
                story: _selectedStory!,
                onClose: () => setState(() => _selectedStory = null),
                onTap: () => context.push('/pin/${_selectedStory!.id}'),
              ),
            )
          else
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Long-press the map to drop a pin',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Marker _buildMarker(StoryModel story, String currentUserId) {
    final isSelected = _selectedStory?.id == story.id;
    final isPrivatePin = !story.isPublic && story.creatorId == currentUserId;

    // Scale size with zoom: ~18px at zoom 10, ~31px at zoom 13, ~44px at zoom 16+
    final markerSize = isSelected ? 56.0 : (18.0 + _zoomNorm * 26.0);
    final iconSize = isSelected ? 28.0 : (10.0 + _zoomNorm * 14.0);

    final markerColor = isSelected
        ? AppColors.primary
        : isPrivatePin
            ? AppColors.secondary
            : AppColors.surface;
    final borderColor = isSelected
        ? AppColors.primary
        : isPrivatePin
            ? AppColors.secondary
            : AppColors.border;

    return Marker(
      point: LatLng(story.latitude, story.longitude),
      width: markerSize,
      height: markerSize,
      child: GestureDetector(
        onTap: () => setState(() => _selectedStory = story),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: markerColor,
            border: Border.all(color: borderColor, width: isSelected ? 3 : 1.5),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primary.withAlpha(80)
                    : Colors.black26,
                blurRadius: isSelected ? 12 : 4,
              ),
            ],
          ),
          child: Icon(
            Icons.location_on_rounded,
            size: iconSize,
            color: isSelected || isPrivatePin
                ? AppColors.background
                : AppColors.primary,
          ),
        ),
      ),
    );
  }

  void _handleMapLongPress(LatLng point) async {
    final result = await showModalBottomSheet<_NewPinData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _NewPinSheet(point: point),
      ),
    );

    if (!mounted || result == null) return;

    final authState = ref.read(authProvider);
    final currentUser = authState.user ?? MockData.currentUser;
    final storyId = const Uuid().v4();
    final service = ref.read(firestoreServiceProvider);

    final story = StoryModel(
      id: storyId,
      title: result.title.isEmpty ? 'My Pin' : result.title,
      description: result.description.isEmpty ? null : result.description,
      mapId: 'personal',
      creatorId: currentUser.id,
      creatorName: currentUser.displayName,
      creatorAvatar: currentUser.avatarUrl,
      latitude: point.latitude,
      longitude: point.longitude,
      tags: result.tags,
      isPublic: result.isPublic,
      createdAt: DateTime.now(),
    );

    await service.insertStory(story);
    if (!mounted) return;
    ref.invalidate(nearbyStoriesProvider);
    ref.invalidate(exploreStoriesProvider(currentUser.id));
  }

  List<StoryModel> _filterStories(
    List<StoryModel> stories,
    String currentUserId,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final category = _selectedCategory.toLowerCase();

    final filtered = stories.where((story) {
      final allowed = story.isPublic || story.creatorId == currentUserId;
      if (!allowed) return false;

      final matchesCategory =
          category == 'all' ||
          story.tags.any((tag) => tag.toLowerCase() == category);

      final matchesSearch =
          query.isEmpty ||
          story.title.toLowerCase().contains(query) ||
          story.tags.any((tag) => tag.toLowerCase().contains(query)) ||
          (story.locationName?.toLowerCase().contains(query) ?? false);

      return matchesCategory && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      if (_sortOption == _ExploreSortOption.latest) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (_sortOption == _ExploreSortOption.nearby &&
          _currentPosition != null) {
        final distA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        final distB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      }
      return b.savedCount.compareTo(a.savedCount);
    });

    return filtered;
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                hintText: 'Search pins by title or category',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          PopupMenuButton<_ExploreSortOption>(
            tooltip: 'Sort pins',
            icon: const Icon(
              Icons.sort_rounded,
              color: AppColors.textSecondary,
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _ExploreSortOption.popular,
                child: Text('Popular'),
              ),
              const PopupMenuItem(
                value: _ExploreSortOption.latest,
                child: Text('Latest'),
              ),
              const PopupMenuItem(
                value: _ExploreSortOption.nearby,
                child: Text('Nearby'),
              ),
            ],
            onSelected: (option) {
              setState(() => _sortOption = option);
              if (option == _ExploreSortOption.nearby &&
                  _currentPosition == null) {
                _goToCurrentLocation();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        scrollDirection: Axis.horizontal,
        itemCount: _exploreCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _exploreCategories[index];
          return AtlasTag(
            label: label,
            isSelected: _selectedCategory == label,
            onTap: () => setState(() => _selectedCategory = label),
          );
        },
      ),
    );
  }

  Widget _buildSortRow(
    AsyncValue<List<StoryModel>> storiesAsync,
    String currentUserId,
  ) {
    final sortLabel = switch (_sortOption) {
      _ExploreSortOption.popular => 'Popular',
      _ExploreSortOption.latest => 'Latest',
      _ExploreSortOption.nearby => 'Nearby',
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            'Sort: $sortLabel',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        storiesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (stories) {
            final count = _filterStories(stories, currentUserId).length;
            return Text(
              '$count pins shown',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NewPinSheet extends StatefulWidget {
  final LatLng point;

  const _NewPinSheet({required this.point});

  @override
  State<_NewPinSheet> createState() => _NewPinSheetState();
}

const _pinTagOptions = [
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

class _NewPinSheetState extends State<_NewPinSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = true;
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Text('Add pin details', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '${widget.point.latitude.toStringAsFixed(4)}, ${widget.point.longitude.toStringAsFixed(4)}',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Name this place',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            style: AppTextStyles.bodyLarge,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Add a short note or memory',
            ),
          ),
          const SizedBox(height: 20),
          Text('Tags', style: AppTextStyles.labelMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pinTagOptions.map((tag) {
              final selected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withAlpha(30)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
            title: Text('Public', style: AppTextStyles.bodyMedium),
            subtitle: Text(
              'Visible to others when shared',
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
              onPressed: () {
                Navigator.of(context).pop(
                  _NewPinData(
                    title: _titleController.text.trim(),
                    description: _descriptionController.text.trim(),
                    isPublic: _isPublic,
                    tags: _selectedTags.toList(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text('Save pin', style: AppTextStyles.labelLarge),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _NewPinData {
  final String title;
  final String description;
  final bool isPublic;
  final List<String> tags;
  _NewPinData({
    required this.title,
    required this.description,
    required this.isPublic,
    required this.tags,
  });
}

class _StoryPreviewSheet extends StatelessWidget {
  final StoryModel story;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const _StoryPreviewSheet({
    required this.story,
    required this.onClose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: story.imageUrls.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: story.imageUrls.first,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: AppColors.surfaceElevated),
                        errorWidget: (_, _, _) => Container(
                          width: 72,
                          height: 72,
                          color: AppColors.surfaceElevated,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textTertiary,
                              size: 24,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: AppColors.surfaceElevated,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      style: AppTextStyles.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (story.locationName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(story.locationName!, style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AtlasAvatar(
                          imageUrl: story.creatorAvatar,
                          name: story.creatorName,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(story.creatorName, style: AppTextStyles.caption),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.favorite_border_rounded,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              MockData.formatCount(story.likes),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceElevated,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
