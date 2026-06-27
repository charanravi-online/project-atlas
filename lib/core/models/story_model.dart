class StoryModel {
  final String id;
  final String title;
  final String? description;
  final String mapId;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final double latitude;
  final double longitude;
  final String? locationName;
  final List<String> imageUrls;
  final List<String> tags;
  final String? bestTime;
  final String? tips;
  final String? warnings;
  final int likes;
  final int commentsCount;
  final int savedCount;
  final bool isPublic;
  final DateTime createdAt;

  const StoryModel({
    required this.id,
    required this.title,
    this.description,
    required this.mapId,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.imageUrls = const [],
    this.tags = const [],
    this.bestTime,
    this.tips,
    this.warnings,
    this.likes = 0,
    this.commentsCount = 0,
    this.savedCount = 0,
    this.isPublic = true,
    required this.createdAt,
  });
}
