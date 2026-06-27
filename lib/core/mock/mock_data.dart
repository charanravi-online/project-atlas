import '../models/user_model.dart';
import '../models/map_model.dart';
import '../models/story_model.dart';

class MockData {
  static final List<UserModel> users = [
    const UserModel(
      id: 'u1',
      username: 'wanderlust_kai',
      displayName: 'Kai Tanaka',
      avatarUrl: 'https://i.pravatar.cc/150?img=11',
      bio: 'Chasing sunsets and hidden gems 🌅  Tokyo → Everywhere',
      location: 'Tokyo, Japan',
      followers: 24300,
      following: 312,
      mapsCount: 18,
      storiesCount: 142,
      isVerified: true,
    ),
    const UserModel(
      id: 'u2',
      username: 'sofia_explores',
      displayName: 'Sofia Marquez',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
      bio: 'Coffee shops & cobblestone streets ☕ Barcelona based',
      location: 'Barcelona, Spain',
      followers: 18900,
      following: 540,
      mapsCount: 12,
      storiesCount: 97,
      isVerified: true,
    ),
    const UserModel(
      id: 'u3',
      username: 'lens_of_luca',
      displayName: 'Luca Bianchi',
      avatarUrl: 'https://i.pravatar.cc/150?img=15',
      bio: 'Photographer capturing the unseen 📷 Rome → World',
      location: 'Rome, Italy',
      followers: 9200,
      following: 210,
      mapsCount: 7,
      storiesCount: 63,
    ),
    const UserModel(
      id: 'u4',
      username: 'amara_trails',
      displayName: 'Amara Osei',
      avatarUrl: 'https://i.pravatar.cc/150?img=9',
      bio: 'Trail runner & adventure seeker 🏃 Accra → Peaks',
      location: 'Accra, Ghana',
      followers: 6700,
      following: 890,
      mapsCount: 9,
      storiesCount: 55,
    ),
    const UserModel(
      id: 'u5',
      username: 'niko_cycles',
      displayName: 'Niko Petrov',
      avatarUrl: 'https://i.pravatar.cc/150?img=3',
      bio: 'Cycling the world one route at a time 🚴 Sofia native',
      location: 'Sofia, Bulgaria',
      followers: 4100,
      following: 670,
      mapsCount: 14,
      storiesCount: 88,
    ),
  ];

  static UserModel get currentUser => users.first;

  static final List<MapModel> trendingMaps = [
    MapModel(
      id: 'm1',
      title: 'Hidden Tokyo',
      description: 'Secret spots only locals know — from alleys to rooftops.',
      creatorId: 'u1',
      creatorName: 'Kai Tanaka',
      creatorAvatar: 'https://i.pravatar.cc/150?img=11',
      coverImageUrl: 'https://picsum.photos/seed/tokyo1/800/500',
      categories: ['Travel', 'Food', 'Photography'],
      pinCount: 34,
      savedCount: 12400,
      viewCount: 89000,
      createdAt: DateTime(2024, 3, 15),
    ),
    MapModel(
      id: 'm2',
      title: 'Barcelona After Dark',
      description: 'The city that never sleeps — best nightlife, tapas bars and sunset rooftops.',
      creatorId: 'u2',
      creatorName: 'Sofia Marquez',
      creatorAvatar: 'https://i.pravatar.cc/150?img=5',
      coverImageUrl: 'https://picsum.photos/seed/barcelona2/800/500',
      categories: ['Nightlife', 'Food', 'Architecture'],
      pinCount: 21,
      savedCount: 8700,
      viewCount: 52000,
      createdAt: DateTime(2024, 4, 2),
    ),
    MapModel(
      id: 'm3',
      title: 'Rome Through a Lens',
      description: 'Best photo spots in Rome — morning golden hour to blue hour magic.',
      creatorId: 'u3',
      creatorName: 'Luca Bianchi',
      creatorAvatar: 'https://i.pravatar.cc/150?img=15',
      coverImageUrl: 'https://picsum.photos/seed/rome3/800/500',
      categories: ['Photography', 'Architecture', 'History'],
      pinCount: 28,
      savedCount: 15200,
      viewCount: 110000,
      createdAt: DateTime(2024, 2, 20),
    ),
    MapModel(
      id: 'm4',
      title: 'Kyoto\'s Quiet Corners',
      description: 'Escape the crowds — bamboo groves, moss gardens and hidden shrines.',
      creatorId: 'u1',
      creatorName: 'Kai Tanaka',
      creatorAvatar: 'https://i.pravatar.cc/150?img=11',
      coverImageUrl: 'https://picsum.photos/seed/kyoto4/800/500',
      categories: ['Travel', 'Nature', 'Culture'],
      pinCount: 19,
      savedCount: 9800,
      viewCount: 67000,
      createdAt: DateTime(2024, 5, 10),
    ),
    MapModel(
      id: 'm5',
      title: 'Accra Street Food Trail',
      description: 'The ultimate guide to Accra\'s best street food — from waakye to kelewele.',
      creatorId: 'u4',
      creatorName: 'Amara Osei',
      creatorAvatar: 'https://i.pravatar.cc/150?img=9',
      coverImageUrl: 'https://picsum.photos/seed/accra5/800/500',
      categories: ['Food', 'Street Food', 'Culture'],
      pinCount: 26,
      savedCount: 5400,
      viewCount: 31000,
      createdAt: DateTime(2024, 6, 1),
    ),
  ];

  static final List<StoryModel> nearbyStories = [
    StoryModel(
      id: 's1',
      title: 'The Floating Tea House',
      description:
          'Tucked behind a century-old temple, this tea house serves the most extraordinary matcha you\'ve ever tasted. Arrive before 9am to have it all to yourself.',
      mapId: 'm1',
      creatorId: 'u1',
      creatorName: 'Kai Tanaka',
      creatorAvatar: 'https://i.pravatar.cc/150?img=11',
      latitude: 35.6762,
      longitude: 139.6503,
      locationName: 'Yanaka, Tokyo',
      imageUrls: [
        'https://picsum.photos/seed/tea1/800/600',
        'https://picsum.photos/seed/tea2/800/600',
        'https://picsum.photos/seed/tea3/800/600',
      ],
      tags: ['Coffee', 'Photography', 'Hidden'],
      bestTime: 'Early Morning (7–9am)',
      tips: 'Cash only. Order the seasonal matcha set. Shoes off at the entrance.',
      warnings: 'Closed Mondays and Tuesdays.',
      likes: 2340,
      commentsCount: 87,
      savedCount: 1200,
      createdAt: DateTime(2024, 4, 12),
    ),
    StoryModel(
      id: 's2',
      title: 'Secret Rooftop Garden',
      description:
          'This urban farm on the 8th floor of a Shinjuku building grows vegetables for the restaurant below. Ask the front desk for rooftop access — they\'ll say yes if you smile.',
      mapId: 'm1',
      creatorId: 'u1',
      creatorName: 'Kai Tanaka',
      creatorAvatar: 'https://i.pravatar.cc/150?img=11',
      latitude: 35.6897,
      longitude: 139.6922,
      locationName: 'Shinjuku, Tokyo',
      imageUrls: [
        'https://picsum.photos/seed/garden1/800/600',
        'https://picsum.photos/seed/garden2/800/600',
      ],
      tags: ['Nature', 'Photography', 'Urban'],
      bestTime: 'Sunset (5–7pm)',
      tips: 'Bring a wide angle lens. The city skyline is the real show.',
      likes: 1890,
      commentsCount: 54,
      savedCount: 967,
      createdAt: DateTime(2024, 4, 20),
    ),
    StoryModel(
      id: 's3',
      title: 'El Born\'s Hidden Courtyard',
      description:
          'Pass through an unmarked wooden door on Carrer del Rec and find yourself in a 16th century courtyard with an orange tree and a fountain. Pure magic.',
      mapId: 'm2',
      creatorId: 'u2',
      creatorName: 'Sofia Marquez',
      creatorAvatar: 'https://i.pravatar.cc/150?img=5',
      latitude: 41.3851,
      longitude: 2.1734,
      locationName: 'El Born, Barcelona',
      imageUrls: [
        'https://picsum.photos/seed/born1/800/600',
        'https://picsum.photos/seed/born2/800/600',
        'https://picsum.photos/seed/born3/800/600',
      ],
      tags: ['Architecture', 'History', 'Photography'],
      bestTime: 'Golden Hour (6–8pm)',
      tips: 'The door has no sign. Look for the blue plaque on the left wall.',
      likes: 3100,
      commentsCount: 122,
      savedCount: 1850,
      createdAt: DateTime(2024, 5, 3),
    ),
    StoryModel(
      id: 's4',
      title: 'The 4am Ramen Spot',
      description:
          'This tiny 6-seat ramen shop only opens when the chef feels like it, usually between 4am and 8am. The tonkotsu broth has been simmering for 48 hours.',
      mapId: 'm1',
      creatorId: 'u3',
      creatorName: 'Luca Bianchi',
      creatorAvatar: 'https://i.pravatar.cc/150?img=15',
      latitude: 35.6595,
      longitude: 139.7004,
      locationName: 'Shibuya, Tokyo',
      imageUrls: [
        'https://picsum.photos/seed/ramen1/800/600',
        'https://picsum.photos/seed/ramen2/800/600',
      ],
      tags: ['Food', 'Street Food', 'Nightlife'],
      bestTime: 'Late Night / Early Morning',
      tips: 'Queue outside. No reservations. Bring cash — ¥1200 per bowl.',
      warnings: 'Often closed without notice. Follow their Instagram.',
      likes: 4500,
      commentsCount: 210,
      savedCount: 2900,
      createdAt: DateTime(2024, 3, 28),
    ),
    StoryModel(
      id: 's5',
      title: 'Stairway to the Clouds',
      description:
          'A 400-step stone staircase through a bamboo forest leads to a shrine that sees fewer than 20 visitors a day. The view at the top is worth every step.',
      mapId: 'm4',
      creatorId: 'u1',
      creatorName: 'Kai Tanaka',
      creatorAvatar: 'https://i.pravatar.cc/150?img=11',
      latitude: 35.0116,
      longitude: 135.7681,
      locationName: 'Arashiyama, Kyoto',
      imageUrls: [
        'https://picsum.photos/seed/kyoto1/800/600',
        'https://picsum.photos/seed/kyoto2/800/600',
        'https://picsum.photos/seed/kyoto3/800/600',
      ],
      tags: ['Nature', 'Hiking', 'Photography', 'Culture'],
      bestTime: 'Sunrise (5–7am)',
      tips: 'Bring water. The forest is dense and the path gets slippery after rain.',
      likes: 6700,
      commentsCount: 345,
      savedCount: 4100,
      createdAt: DateTime(2024, 5, 18),
    ),
  ];

  static final List<MapModel> featuredMaps = trendingMaps.take(3).toList();

  static final List<UserModel> suggestedCreators =
      users.skip(1).take(3).toList();

  static String formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
