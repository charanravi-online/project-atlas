import 'package:cloud_firestore/cloud_firestore.dart';

import '../mock/mock_data.dart';
import '../models/comment_model.dart';
import '../models/map_model.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService _instance = FirestoreService._();
  factory FirestoreService() => _instance;

  final _db = FirebaseFirestore.instance;
  bool _seeded = false;

  Future<void> seedIfNeeded() async {
    if (_seeded) return;
    final snap = await _db.collection('stories').limit(1).get();
    if (snap.docs.isNotEmpty) {
      _seeded = true;
      return;
    }
    final batch = _db.batch();
    for (final user in MockData.users) {
      batch.set(_db.collection('users').doc(user.id), _userToMap(user));
    }
    for (final map in MockData.trendingMaps) {
      batch.set(_db.collection('maps').doc(map.id), _mapToMap(map));
    }
    for (final story in MockData.nearbyStories) {
      batch.set(_db.collection('stories').doc(story.id), _storyToMap(story));
    }
    await batch.commit();
    _seeded = true;
  }

  // ── Stories ───────────────────────────────────────────────────────────────

  // Public stories only, sorted by popularity client-side.
  Future<List<StoryModel>> getNearbyStories() async {
    final snap = await _db
        .collection('stories')
        .where('isPublic', isEqualTo: true)
        .limit(50)
        .get();
    final stories = snap.docs.map((d) => _storyFromMap(d.id, d.data())).toList();
    stories.sort((a, b) =>
        (b.likes + b.savedCount * 2).compareTo(a.likes + a.savedCount * 2));
    return stories;
  }

  // Public stories + the requesting user's own private pins (for the explore map).
  Future<List<StoryModel>> getPublicAndMyStories(String userId) async {
    final results = await Future.wait([
      _db.collection('stories').where('isPublic', isEqualTo: true).limit(50).get(),
      _db.collection('stories').where('creatorId', isEqualTo: userId).get(),
    ]);
    final merged = <String, StoryModel>{};
    for (final doc in results[0].docs) {
      merged[doc.id] = _storyFromMap(doc.id, doc.data());
    }
    for (final doc in results[1].docs) {
      merged[doc.id] = _storyFromMap(doc.id, doc.data());
    }
    return merged.values.toList();
  }

  Future<StoryModel?> getStoryById(String id) async {
    final doc = await _db.collection('stories').doc(id).get();
    if (!doc.exists) return null;
    return _storyFromMap(doc.id, doc.data()!);
  }

  Future<void> insertStory(StoryModel story) async {
    await _db.collection('stories').doc(story.id).set(_storyToMap(story));
  }

  Future<void> updateStory(StoryModel story) async {
    await _db.collection('stories').doc(story.id).update(_storyToMap(story));
  }

  Future<void> deleteStory(String storyId, String creatorId) async {
    final batch = _db.batch();
    batch.delete(_db.collection('stories').doc(storyId));
    batch.update(
      _db.collection('users').doc(creatorId),
      {'storiesCount': FieldValue.increment(-1)},
    );
    await batch.commit();
  }

  Future<List<StoryModel>> getUserStories(String userId) async {
    final snap = await _db
        .collection('stories')
        .where('creatorId', isEqualTo: userId)
        .get();
    final stories = snap.docs.map((d) => _storyFromMap(d.id, d.data())).toList();
    stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return stories;
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  Future<List<CommentModel>> getComments(String storyId) async {
    final snap = await _db
        .collection('stories')
        .doc(storyId)
        .collection('comments')
        .orderBy('createdAt')
        .limit(50)
        .get();
    return snap.docs.map((d) => _commentFromMap(d.id, d.data())).toList();
  }

  Future<void> addComment(String storyId, CommentModel comment) async {
    final batch = _db.batch();
    batch.set(
      _db
          .collection('stories')
          .doc(storyId)
          .collection('comments')
          .doc(comment.id),
      _commentToMap(comment),
    );
    batch.update(
      _db.collection('stories').doc(storyId),
      {'commentsCount': FieldValue.increment(1)},
    );
    await batch.commit();
  }

  // ── Likes ─────────────────────────────────────────────────────────────────

  Future<bool> isLiked(String userId, String storyId) async {
    final doc =
        await _db.collection('likes').doc('${userId}_$storyId').get();
    return doc.exists;
  }

  Future<void> toggleLike(String userId, String storyId) async {
    final docRef = _db.collection('likes').doc('${userId}_$storyId');
    final storyRef = _db.collection('stories').doc(storyId);
    final doc = await docRef.get();
    final batch = _db.batch();
    if (doc.exists) {
      batch.delete(docRef);
      batch.update(storyRef, {'likes': FieldValue.increment(-1)});
    } else {
      batch.set(docRef, {
        'userId': userId,
        'storyId': storyId,
        'likedAt': Timestamp.now(),
      });
      batch.update(storyRef, {'likes': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────────

  Future<bool> isBookmarked(String userId, String storyId) async {
    final doc =
        await _db.collection('bookmarks').doc('${userId}_$storyId').get();
    return doc.exists;
  }

  Future<void> toggleBookmark(String userId, String storyId) async {
    final docRef = _db.collection('bookmarks').doc('${userId}_$storyId');
    final storyRef = _db.collection('stories').doc(storyId);
    final doc = await docRef.get();
    final batch = _db.batch();
    if (doc.exists) {
      batch.delete(docRef);
      batch.update(storyRef, {'savedCount': FieldValue.increment(-1)});
    } else {
      batch.set(docRef, {
        'userId': userId,
        'storyId': storyId,
        'savedAt': Timestamp.now(),
      });
      batch.update(storyRef, {'savedCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  Future<List<StoryModel>> getSavedStories(String userId) async {
    final snap = await _db
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .get();
    if (snap.docs.isEmpty) return [];
    final storyIds =
        snap.docs.map((d) => d.data()['storyId'] as String).toList();
    final stories = <StoryModel>[];
    for (var i = 0; i < storyIds.length; i += 30) {
      final chunk =
          storyIds.sublist(i, (i + 30).clamp(0, storyIds.length));
      final storySnap = await _db
          .collection('stories')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      stories
          .addAll(storySnap.docs.map((d) => _storyFromMap(d.id, d.data())));
    }
    return stories;
  }

  // ── Maps ──────────────────────────────────────────────────────────────────

  Future<List<MapModel>> getTrendingMaps() async {
    final snap = await _db
        .collection('maps')
        .orderBy('savedCount', descending: true)
        .limit(10)
        .get();
    return snap.docs
        .map((d) => _mapFromMap(d.id, d.data()))
        .where((m) => m.isPublic)
        .toList();
  }

  Future<List<MapModel>> getFeaturedMaps() async {
    final snap = await _db
        .collection('maps')
        .orderBy('savedCount', descending: true)
        .limit(3)
        .get();
    return snap.docs
        .map((d) => _mapFromMap(d.id, d.data()))
        .where((m) => m.isPublic)
        .toList();
  }

  // ── Follow ────────────────────────────────────────────────────────────────

  Future<bool> isFollowing(String followerId, String followeeId) async {
    final doc =
        await _db.collection('follows').doc('${followerId}_$followeeId').get();
    return doc.exists;
  }

  Future<void> followUser(String followerId, String followeeId) async {
    final batch = _db.batch();
    batch.set(_db.collection('follows').doc('${followerId}_$followeeId'), {
      'followerId': followerId,
      'followeeId': followeeId,
      'followedAt': Timestamp.now(),
    });
    batch.update(_db.collection('users').doc(followeeId),
        {'followers': FieldValue.increment(1)});
    batch.update(_db.collection('users').doc(followerId),
        {'following': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> unfollowUser(String followerId, String followeeId) async {
    final batch = _db.batch();
    batch.delete(_db.collection('follows').doc('${followerId}_$followeeId'));
    batch.update(_db.collection('users').doc(followeeId),
        {'followers': FieldValue.increment(-1)});
    batch.update(_db.collection('users').doc(followerId),
        {'following': FieldValue.increment(-1)});
    await batch.commit();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  /// Full-text client-side search across public stories (title, description,
  /// location, tags). Sorted by popularity (likes + 2×saves).
  Future<List<StoryModel>> searchStories(String query) async {
    final snap = await _db
        .collection('stories')
        .where('isPublic', isEqualTo: true)
        .get();
    final q = query.toLowerCase();
    final stories = snap.docs
        .map((d) => _storyFromMap(d.id, d.data()))
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            (s.description?.toLowerCase().contains(q) ?? false) ||
            (s.locationName?.toLowerCase().contains(q) ?? false) ||
            s.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
    stories.sort(
        (a, b) => (b.likes + b.savedCount * 2).compareTo(a.likes + a.savedCount * 2));
    return stories;
  }

  /// Fetch public stories matching [tag] exactly, sorted by popularity.
  Future<List<StoryModel>> searchStoriesByTag(String tag) async {
    final snap = await _db
        .collection('stories')
        .where('isPublic', isEqualTo: true)
        .where('tags', arrayContains: tag)
        .get();
    final stories =
        snap.docs.map((d) => _storyFromMap(d.id, d.data())).toList();
    stories.sort(
        (a, b) => (b.likes + b.savedCount * 2).compareTo(a.likes + a.savedCount * 2));
    return stories;
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  /// Returns true if [username] is already claimed by someone other than
  /// [excludeUserId]. Pass [excludeUserId] when checking for the current user
  /// so they can keep their own username.
  Future<bool> isUsernameTaken(String username, {String? excludeUserId}) async {
    final snap = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(2)
        .get();
    if (excludeUserId != null) {
      return snap.docs.any((d) => d.id != excludeUserId);
    }
    return snap.docs.isNotEmpty;
  }

  Future<List<UserModel>> getSuggestedCreators() async {
    final snap = await _db
        .collection('users')
        .orderBy('followers', descending: true)
        .limit(4)
        .get();
    return snap.docs.map((d) => _userFromMap(d.id, d.data())).toList();
  }

  Future<UserModel?> getUserById(String id) async {
    final doc = await _db.collection('users').doc(id).get();
    if (!doc.exists) return null;
    return _userFromMap(doc.id, doc.data()!);
  }

  Future<void> insertUser(UserModel user) async {
    await _db.collection('users').doc(user.id).set(_userToMap(user));
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> _userToMap(UserModel u) => {
        'username': u.username,
        'displayName': u.displayName,
        'avatarUrl': u.avatarUrl,
        'bio': u.bio,
        'location': u.location,
        'website': u.website,
        'followers': u.followers,
        'following': u.following,
        'mapsCount': u.mapsCount,
        'storiesCount': u.storiesCount,
        'isVerified': u.isVerified,
      };

  UserModel _userFromMap(String id, Map<String, dynamic> d) => UserModel(
        id: id,
        username: d['username'] as String,
        displayName: d['displayName'] as String,
        avatarUrl: d['avatarUrl'] as String?,
        bio: d['bio'] as String?,
        location: d['location'] as String?,
        website: d['website'] as String?,
        followers: (d['followers'] as num?)?.toInt() ?? 0,
        following: (d['following'] as num?)?.toInt() ?? 0,
        mapsCount: (d['mapsCount'] as num?)?.toInt() ?? 0,
        storiesCount: (d['storiesCount'] as num?)?.toInt() ?? 0,
        isVerified: d['isVerified'] as bool? ?? false,
      );

  Map<String, dynamic> _mapToMap(MapModel m) => {
        'title': m.title,
        'description': m.description,
        'creatorId': m.creatorId,
        'creatorName': m.creatorName,
        'creatorAvatar': m.creatorAvatar,
        'coverImageUrl': m.coverImageUrl,
        'categories': m.categories,
        'pinCount': m.pinCount,
        'savedCount': m.savedCount,
        'viewCount': m.viewCount,
        'createdAt': Timestamp.fromDate(m.createdAt),
        'isPublic': m.isPublic,
      };

  MapModel _mapFromMap(String id, Map<String, dynamic> d) => MapModel(
        id: id,
        title: d['title'] as String,
        description: d['description'] as String?,
        creatorId: d['creatorId'] as String,
        creatorName: d['creatorName'] as String,
        creatorAvatar: d['creatorAvatar'] as String?,
        coverImageUrl: d['coverImageUrl'] as String?,
        categories: List<String>.from(d['categories'] as List? ?? []),
        pinCount: (d['pinCount'] as num?)?.toInt() ?? 0,
        savedCount: (d['savedCount'] as num?)?.toInt() ?? 0,
        viewCount: (d['viewCount'] as num?)?.toInt() ?? 0,
        createdAt: (d['createdAt'] as Timestamp).toDate(),
        isPublic: d['isPublic'] as bool? ?? true,
      );

  Map<String, dynamic> _storyToMap(StoryModel s) => {
        'title': s.title,
        'description': s.description,
        'mapId': s.mapId,
        'creatorId': s.creatorId,
        'creatorName': s.creatorName,
        'creatorAvatar': s.creatorAvatar,
        'latitude': s.latitude,
        'longitude': s.longitude,
        'locationName': s.locationName,
        'imageUrls': s.imageUrls,
        'tags': s.tags,
        'bestTime': s.bestTime,
        'tips': s.tips,
        'warnings': s.warnings,
        'likes': s.likes,
        'commentsCount': s.commentsCount,
        'savedCount': s.savedCount,
        'isPublic': s.isPublic,
        'createdAt': Timestamp.fromDate(s.createdAt),
      };

  StoryModel _storyFromMap(String id, Map<String, dynamic> d) => StoryModel(
        id: id,
        title: d['title'] as String,
        description: d['description'] as String?,
        mapId: d['mapId'] as String,
        creatorId: d['creatorId'] as String,
        creatorName: d['creatorName'] as String,
        creatorAvatar: d['creatorAvatar'] as String?,
        latitude: (d['latitude'] as num).toDouble(),
        longitude: (d['longitude'] as num).toDouble(),
        locationName: d['locationName'] as String?,
        imageUrls: List<String>.from(d['imageUrls'] as List? ?? []),
        tags: List<String>.from(d['tags'] as List? ?? []),
        bestTime: d['bestTime'] as String?,
        tips: d['tips'] as String?,
        warnings: d['warnings'] as String?,
        likes: (d['likes'] as num?)?.toInt() ?? 0,
        commentsCount: (d['commentsCount'] as num?)?.toInt() ?? 0,
        savedCount: (d['savedCount'] as num?)?.toInt() ?? 0,
        isPublic: d['isPublic'] as bool? ?? true,
        createdAt: (d['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> _commentToMap(CommentModel c) => {
        'userId': c.userId,
        'userName': c.userName,
        'userAvatar': c.userAvatar,
        'text': c.text,
        'createdAt': Timestamp.fromDate(c.createdAt),
      };

  CommentModel _commentFromMap(String id, Map<String, dynamic> d) =>
      CommentModel(
        id: id,
        userId: d['userId'] as String,
        userName: d['userName'] as String,
        userAvatar: d['userAvatar'] as String?,
        text: d['text'] as String,
        createdAt: (d['createdAt'] as Timestamp).toDate(),
      );
}
