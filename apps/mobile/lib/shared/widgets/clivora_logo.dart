import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/clivora_colors.dart';

class ClivoraLogo extends StatelessWidget {
  const ClivoraLogo({super.key, this.size = 48, this.borderRadius = 14});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/images/clivora_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ClivoraColors.primaryPurple, const Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          alignment: Alignment.center,
          child: Text(
            'C',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.45,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.photoPath,
    this.name,
    this.radius = 24,
    this.onTap,
    this.showVerified = false,
  });

  final String? photoPath;
  final String? name;
  final double radius;
  final VoidCallback? onTap;
  final bool showVerified;

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    final path = photoPath?.trim();
    final isRemote = path != null &&
        path.isNotEmpty &&
        (path.startsWith('http://') ||
            path.startsWith('https://') ||
            path.startsWith('data:'));
    final isLocalFile =
        path != null && path.isNotEmpty && !isRemote && File(path).existsSync();

    if (isRemote) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: ClivoraColors.primaryPurple.withValues(alpha: 0.2),
        backgroundImage: NetworkImage(path),
        onBackgroundImageError: (_, _) {},
      );
    } else if (isLocalFile) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(path)),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: ClivoraColors.primaryPurple.withValues(alpha: 0.2),
        child: Text(
          (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '?',
          style: TextStyle(
            color: ClivoraColors.primaryPurple,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.7,
          ),
        ),
      );
    }

    if (showVerified) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified, size: radius * 0.55, color: ClivoraColors.primary),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}
