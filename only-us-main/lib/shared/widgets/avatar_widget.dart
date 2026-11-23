import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Circular avatar: network image when [imageUrl] is set, otherwise the
/// first letter of [name] on a purple gradient.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.showOnlineDot = false,
    this.isOnline = false,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final bool showOnlineDot;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final String initial =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final Widget circle = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.purple,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImageProvider(imageUrl!)
          : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.85,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );

    if (!showOnlineDot) return circle;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        circle,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.55,
            height: radius * 0.55,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.success : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.midnight, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
