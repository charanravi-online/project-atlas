import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firestore_provider.dart';

/// Session-level interaction cache.
/// Like Instagram: check here first (instant), fall back to Firestore once per
/// session, then keep state in memory. Optimistic toggles write to cache
/// synchronously and Firestore in the background — no flicker, no re-fetch.
class InteractionState {
  final Map<String, bool> likedPins;
  final Map<String, bool> bookmarkedPins;
  // Count overrides: exact count after user interaction this session.
  // Overlay on top of Firestore values so feed cards reflect toggles immediately.
  final Map<String, int> likeCountOverrides;
  final Map<String, int> saveCountOverrides;

  const InteractionState({
    this.likedPins = const {},
    this.bookmarkedPins = const {},
    this.likeCountOverrides = const {},
    this.saveCountOverrides = const {},
  });

  bool isLiked(String storyId) => likedPins[storyId] ?? false;
  bool isBookmarked(String storyId) => bookmarkedPins[storyId] ?? false;
  bool hasLikeState(String storyId) => likedPins.containsKey(storyId);
  bool hasBookmarkState(String storyId) => bookmarkedPins.containsKey(storyId);

  // Effective like count: session override first, fallback to Firestore value.
  int likeCount(String storyId, int firestoreCount) =>
      likeCountOverrides[storyId] ?? firestoreCount;

  int saveCount(String storyId, int firestoreCount) =>
      saveCountOverrides[storyId] ?? firestoreCount;

  InteractionState copyWith({
    Map<String, bool>? likedPins,
    Map<String, bool>? bookmarkedPins,
    Map<String, int>? likeCountOverrides,
    Map<String, int>? saveCountOverrides,
  }) =>
      InteractionState(
        likedPins: likedPins ?? this.likedPins,
        bookmarkedPins: bookmarkedPins ?? this.bookmarkedPins,
        likeCountOverrides: likeCountOverrides ?? this.likeCountOverrides,
        saveCountOverrides: saveCountOverrides ?? this.saveCountOverrides,
      );
}

class InteractionNotifier extends Notifier<InteractionState> {
  @override
  InteractionState build() => const InteractionState();

  /// Fetch like state from Firestore if not already cached. No-op if cached.
  Future<void> ensureLikeLoaded(String userId, String storyId) async {
    if (state.hasLikeState(storyId)) return;
    final liked =
        await ref.read(firestoreServiceProvider).isLiked(userId, storyId);
    state = state.copyWith(
      likedPins: {...state.likedPins, storyId: liked},
    );
  }

  /// Fetch bookmark state from Firestore if not already cached. No-op if cached.
  Future<void> ensureBookmarkLoaded(String userId, String storyId) async {
    if (state.hasBookmarkState(storyId)) return;
    final saved =
        await ref.read(firestoreServiceProvider).isBookmarked(userId, storyId);
    state = state.copyWith(
      bookmarkedPins: {...state.bookmarkedPins, storyId: saved},
    );
  }

  /// Toggle like: updates cache instantly, writes Firestore in background.
  /// [firestoreCount] is the last known Firestore count for this story.
  Future<void> toggleLike(
    String userId,
    String storyId,
    int firestoreCount,
  ) async {
    final wasLiked = state.likedPins[storyId] ?? false;
    final nowLiked = !wasLiked;
    final baseCount = state.likeCountOverrides[storyId] ?? firestoreCount;
    final newCount = baseCount + (nowLiked ? 1 : -1);

    // Synchronous optimistic update — UI reflects instantly.
    state = state.copyWith(
      likedPins: {...state.likedPins, storyId: nowLiked},
      likeCountOverrides: {...state.likeCountOverrides, storyId: newCount},
    );

    // Background Firestore write.
    await ref.read(firestoreServiceProvider).toggleLike(userId, storyId);
  }

  /// Toggle bookmark: updates cache instantly, writes Firestore in background.
  Future<void> toggleBookmark(
    String userId,
    String storyId,
    int firestoreCount,
  ) async {
    final wasBookmarked = state.bookmarkedPins[storyId] ?? false;
    final nowBookmarked = !wasBookmarked;
    final baseCount = state.saveCountOverrides[storyId] ?? firestoreCount;
    final newCount = baseCount + (nowBookmarked ? 1 : -1);

    state = state.copyWith(
      bookmarkedPins: {...state.bookmarkedPins, storyId: nowBookmarked},
      saveCountOverrides: {...state.saveCountOverrides, storyId: newCount},
    );

    await ref.read(firestoreServiceProvider).toggleBookmark(userId, storyId);
  }

  /// Clear all cached state on logout.
  void clear() => state = const InteractionState();
}

final interactionProvider =
    NotifierProvider<InteractionNotifier, InteractionState>(
  InteractionNotifier.new,
);
