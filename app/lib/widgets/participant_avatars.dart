import 'package:flutter/material.dart';
import '../models/activity_item.dart';
import '../theme/app_theme.dart';

/// Widget that displays participant avatars for an activity
/// Shows 1-2 circular avatars indicating who completed the activity
class ParticipantAvatars extends StatelessWidget {
  final List<ParticipantStatus> participants;
  final double size;
  final double overlapOffset;

  const ParticipantAvatars({
    super.key,
    required this.participants,
    this.size = 36.0,
    this.overlapOffset = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final completedParticipants = participants
        .where((p) => p.hasCompleted)
        .toList();

    if (completedParticipants.isEmpty) {
      // Show empty circle outline if nobody completed yet
      return _EmptyAvatar(size: size);
    }

    if (completedParticipants.length == 1) {
      // Single avatar
      return _Avatar(
        initial: completedParticipants[0].initial,
        size: size,
      );
    }

    // Dual avatars (overlapping)
    return SizedBox(
      width: size + overlapOffset,
      height: size,
      child: Stack(
        children: [
          // First avatar (back)
          Positioned(
            left: 0,
            child: _Avatar(
              initial: completedParticipants[0].initial,
              size: size,
            ),
          ),
          // Second avatar (front, slightly overlapping)
          Positioned(
            left: overlapOffset,
            child: _Avatar(
              initial: completedParticipants[1].initial,
              size: size,
              hasBorder: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single avatar circle with initial
class _Avatar extends StatelessWidget {
  final String initial;
  final double size;
  final bool hasBorder;

  const _Avatar({
    required this.initial,
    required this.size,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlack,
        shape: BoxShape.circle,
        border: hasBorder
            ? Border.all(color: AppTheme.primaryWhite, width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTheme.bodyFont.copyWith(
            color: AppTheme.primaryWhite,
            fontSize: size * 0.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Empty avatar circle (outline only)
class _EmptyAvatar extends StatelessWidget {
  final double size;

  const _EmptyAvatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.borderLight,
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: size * 0.5,
          color: AppTheme.textTertiary,
        ),
      ),
    );
  }
}
