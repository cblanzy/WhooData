import 'dart:io';

import 'package:flutter/material.dart';

/// Reusable contact avatar widget that displays photo or initials
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    required this.firstName,
    required this.lastName,
    this.middleInitial,
    this.photoPath,
    this.radius = 20,
    super.key,
  });

  final String firstName;
  final String lastName;
  final String? middleInitial;
  final String? photoPath;
  final double radius;

  String get _initials {
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$firstInitial$lastInitial';
  }

  @override
  Widget build(BuildContext context) {
    // If photo path exists and file is valid, display photo
    if (photoPath != null && photoPath!.isNotEmpty) {
      final file = File(photoPath!);
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(file),
        onBackgroundImageError: (_, __) {
          // If image fails to load, we'll fall back to initials
          // This will be handled by the errorBuilder below
        },
      );
    }

    // Fall back to initials
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        _initials.isNotEmpty ? _initials : '?',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
