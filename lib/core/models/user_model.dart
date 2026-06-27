class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final String? website;
  final int followers;
  final int following;
  final int mapsCount;
  final int storiesCount;
  final bool isVerified;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.location,
    this.website,
    this.followers = 0,
    this.following = 0,
    this.mapsCount = 0,
    this.storiesCount = 0,
    this.isVerified = false,
  });
}
