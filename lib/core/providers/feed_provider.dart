import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment_model.dart';
import '../models/map_model.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import 'firestore_provider.dart';

final trendingMapsProvider = FutureProvider<List<MapModel>>((ref) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getTrendingMaps();
});

final nearbyStoriesProvider = FutureProvider<List<StoryModel>>((ref) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getNearbyStories();
});

final featuredMapsProvider = FutureProvider<List<MapModel>>((ref) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getFeaturedMaps();
});

final suggestedCreatorsProvider = FutureProvider<List<UserModel>>((ref) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getSuggestedCreators();
});

final storyByIdProvider =
    FutureProvider.family<StoryModel?, String>((ref, id) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getStoryById(id);
});

final commentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, storyId) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getComments(storyId);
});

final savedStoriesProvider =
    FutureProvider.family<List<StoryModel>, String>((ref, userId) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getSavedStories(userId);
});

final userStoriesProvider =
    FutureProvider.family<List<StoryModel>, String>((ref, userId) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getUserStories(userId);
});

// Public stories + the current user's private pins — used by the explore map.
final exploreStoriesProvider =
    FutureProvider.family<List<StoryModel>, String>((ref, userId) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getPublicAndMyStories(userId);
});

final selectedStoryProvider = StateProvider<String?>((ref) => null);

final userProfileProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  return ref.read(firestoreServiceProvider).getUserById(userId);
});

/// Set this provider before navigating to /search to pre-fill the search bar.
final searchQueryProvider = StateProvider<String>((ref) => '');

final tagStoriesProvider =
    FutureProvider.family<List<StoryModel>, String>((ref, tag) async {
  return ref.read(firestoreServiceProvider).searchStoriesByTag(tag);
});

final storySearchProvider =
    FutureProvider.family<List<StoryModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.read(firestoreServiceProvider).searchStories(query);
});
