import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firestore_provider.dart';

class FollowState {
  final Map<String, bool> followed;
  final Set<String> loaded;

  const FollowState({
    this.followed = const {},
    this.loaded = const {},
  });

  bool isFollowing(String userId) => followed[userId] ?? false;
  bool isLoaded(String userId) => loaded.contains(userId);

  FollowState copyWith({
    Map<String, bool>? followed,
    Set<String>? loaded,
  }) =>
      FollowState(
        followed: followed ?? this.followed,
        loaded: loaded ?? this.loaded,
      );
}

class FollowNotifier extends Notifier<FollowState> {
  @override
  FollowState build() => const FollowState();

  Future<void> ensureLoaded(String currentUserId, String targetUserId) async {
    if (state.isLoaded(targetUserId)) return;
    final following = await ref
        .read(firestoreServiceProvider)
        .isFollowing(currentUserId, targetUserId);
    state = state.copyWith(
      followed: {...state.followed, targetUserId: following},
      loaded: {...state.loaded, targetUserId},
    );
  }

  Future<void> toggle(String currentUserId, String targetUserId) async {
    final wasFollowing = state.isFollowing(targetUserId);
    // Optimistic update.
    state = state.copyWith(
      followed: {...state.followed, targetUserId: !wasFollowing},
    );
    final service = ref.read(firestoreServiceProvider);
    if (wasFollowing) {
      await service.unfollowUser(currentUserId, targetUserId);
    } else {
      await service.followUser(currentUserId, targetUserId);
    }
  }

  void clear() => state = const FollowState();
}

final followProvider =
    NotifierProvider<FollowNotifier, FollowState>(FollowNotifier.new);
