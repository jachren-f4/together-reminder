import 'package:flutter/material.dart';
import '../../config/brand/brand_loader.dart';

/// Score row widget showing both players' scores
/// Format: "You: 240" vs "Partner: 280"
class LinkedScoreRow extends StatelessWidget {
  final int userScore;
  final int partnerScore;
  final String userName;
  final String partnerName;
  final bool highlightLeader;
  final TextStyle? scoreStyle;
  final TextStyle? labelStyle;

  const LinkedScoreRow({
    super.key,
    required this.userScore,
    required this.partnerScore,
    this.userName = 'You',
    this.partnerName = 'Partner',
    this.highlightLeader = true,
    this.scoreStyle,
    this.labelStyle,
  });

  bool get _userIsLeading => userScore > partnerScore;
  bool get _partnerIsLeading => partnerScore > userScore;
  bool get _isTied => userScore == partnerScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // User score
        _ScoreItem(
          label: userName,
          score: userScore,
          isLeading: highlightLeader && _userIsLeading,
          isTied: _isTied,
          scoreStyle: scoreStyle,
          labelStyle: labelStyle,
        ),
        const SizedBox(width: 12),
        // Divider
        Container(
          width: 1,
          height: 20,
          color: BrandLoader().colors.textTertiary.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 12),
        // Partner score
        _ScoreItem(
          label: partnerName,
          score: partnerScore,
          isLeading: highlightLeader && _partnerIsLeading,
          isTied: _isTied,
          scoreStyle: scoreStyle,
          labelStyle: labelStyle,
        ),
      ],
    );
  }
}

class _ScoreItem extends StatelessWidget {
  final String label;
  final int score;
  final bool isLeading;
  final bool isTied;
  final TextStyle? scoreStyle;
  final TextStyle? labelStyle;

  const _ScoreItem({
    required this.label,
    required this.score,
    required this.isLeading,
    required this.isTied,
    this.scoreStyle,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveScoreStyle = scoreStyle ??
        TextStyle(
          fontSize: 14,
          fontWeight: isLeading ? FontWeight.bold : FontWeight.w500,
          fontFamily: 'Georgia',
          color: BrandLoader().colors.textPrimary,
        );

    final effectiveLabelStyle = labelStyle ??
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: BrandLoader().colors.textSecondary,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: effectiveLabelStyle,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              score.toString(),
              style: effectiveScoreStyle,
            ),
            if (isLeading && !isTied) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_upward,
                size: 12,
                color: BrandLoader().colors.success,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Compact score row for smaller spaces
class LinkedScoreRowCompact extends StatelessWidget {
  final int userScore;
  final int partnerScore;

  const LinkedScoreRowCompact({
    super.key,
    required this.userScore,
    required this.partnerScore,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$userScore - $partnerScore',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: 'Georgia',
        color: BrandLoader().colors.textPrimary,
      ),
    );
  }
}
