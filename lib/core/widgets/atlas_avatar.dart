import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AtlasAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final bool showBorder;
  final bool isVerified;

  const AtlasAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.showBorder = false,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: showBorder
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
            color: AppColors.surfaceElevated,
          ),
          child: ClipOval(
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: AppColors.surfaceElevated),
                    errorWidget: (_, _, _) => _initials(),
                  )
                : _initials(),
          ),
        ),
        if (isVerified)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: Icon(
                Icons.check,
                size: size * 0.2,
                color: AppColors.background,
              ),
            ),
          ),
      ],
    );
  }

  Widget _initials() {
    final letter = name?.isNotEmpty == true ? name![0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
