import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/atlas_button.dart';

class _OnboardSlide {
  final String imageUrl;
  final String title;
  final String subtitle;

  const _OnboardSlide({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });
}

const _slides = [
  _OnboardSlide(
    imageUrl: 'https://picsum.photos/seed/ob1/900/1200',
    title: 'Discover\nHidden Gems',
    subtitle:
        'Explore curated maps built by real travelers who know the secret spots.',
  ),
  _OnboardSlide(
    imageUrl: 'https://picsum.photos/seed/ob2/900/1200',
    title: 'Share Your\nJourney',
    subtitle:
        'Drop pins, write stories, and show the world the places that moved you.',
  ),
  _OnboardSlide(
    imageUrl: 'https://picsum.photos/seed/ob3/900/1200',
    title: 'Connect with\nExplorers',
    subtitle:
        'Follow creators, build your own maps, and inspire the next adventure.',
  ),
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) => _SlideView(slide: _slides[index]),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomControls(
              currentPage: _currentPage,
              total: _slides.length,
              onNext: _nextPage,
              onSkip: () => context.go('/login'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _OnboardSlide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: slide.imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) =>
              const ColoredBox(color: AppColors.surfaceElevated),
          errorWidget: (_, _, _) => const ColoredBox(
            color: AppColors.surfaceElevated,
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textTertiary,
                size: 32,
              ),
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 1.0],
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0xF5080808),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 220,
          left: 28,
          right: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide.title,
                style: AppTextStyles.displayLarge.copyWith(height: 1.15),
              ),
              const SizedBox(height: 16),
              Text(
                slide.subtitle,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  final int currentPage;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _BottomControls({
    required this.currentPage,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == total - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              total,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == currentPage ? 24 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == currentPage
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          AtlasButton(
            label: isLast ? 'Get Started' : 'Continue',
            onPressed: onNext,
            width: double.infinity,
          ),
          const SizedBox(height: 14),
          if (!isLast)
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
