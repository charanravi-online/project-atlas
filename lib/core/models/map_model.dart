class MapModel {
  final String id;
  final String title;
  final String? description;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final String? coverImageUrl;
  final List<String> categories;
  final int pinCount;
  final int savedCount;
  final int viewCount;
  final DateTime createdAt;
  final bool isPublic;

  const MapModel({
    required this.id,
    required this.title,
    this.description,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    this.coverImageUrl,
    this.categories = const [],
    this.pinCount = 0,
    this.savedCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    this.isPublic = true,
  });
}
