import 'package:flutter/material.dart';
import '../../config/brand/brand_loader.dart';

/// Partner badge widget showing partner's initial in a circle with name
/// Used on card when it's partner's turn
class LinkedPartnerBadge extends StatelessWidget {
  final String partnerName;
  final String? partnerEmoji;
  final double size;
  final Color backgroundColor;
  final Color textColor;

  LinkedPartnerBadge({
    super.key,
    required this.partnerName,
    this.partnerEmoji,
    this.size = 32,
    Color? backgroundColor,
    Color? textColor,
  })  : backgroundColor = backgroundColor ?? BrandLoader().colors.borderLight,
        textColor = textColor ?? BrandLoader().colors.textPrimary;

  String get _initial {
    if (partnerEmoji != null && partnerEmoji!.isNotEmpty) {
      return partnerEmoji!;
    }
    return partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?';
  }

  String get _displayName {
    // Truncate name if too long
    if (partnerName.length > 10) {
      return '${partnerName.substring(0, 10)}...';
    }
    return partnerName;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Initial circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BrandLoader().colors.surface,
              border: Border.all(color: BrandLoader().colors.textTertiary.withValues(alpha: 0.5), width: 1),
            ),
            child: Center(
              child: Text(
                _initial,
                style: TextStyle(
                  fontSize: partnerEmoji != null ? size * 0.6 : size * 0.5,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Partner name
          Text(
            _displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
