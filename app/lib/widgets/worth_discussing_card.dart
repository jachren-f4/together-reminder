import 'package:flutter/material.dart';
import '../services/us_profile_service.dart';
import '../services/haptic_service.dart';

/// A card displaying a discovery with appreciation functionality.
/// Matches the "Worth Discussing" mockup design.
class WorthDiscussingCard extends StatefulWidget {
  final FramedDiscovery discovery;
  final String user1Name;
  final String user2Name;
  final VoidCallback? onAppreciationChanged;

  const WorthDiscussingCard({
    super.key,
    required this.discovery,
    required this.user1Name,
    required this.user2Name,
    this.onAppreciationChanged,
  });

  @override
  State<WorthDiscussingCard> createState() => _WorthDiscussingCardState();
}

class _WorthDiscussingCardState extends State<WorthDiscussingCard> {
  late DiscoveryAppreciation _appreciation;
  bool _isLoading = false;

  // Colors from the mockup
  static const Color _emmaPink = Color(0xFFFF6B6B);
  static const Color _accentGold = Color(0xFFF4C55B);
  static const Color _textDark = Color(0xFF2D2D2D);
  static const Color _textMedium = Color(0xFF5A5A5A);
  static const Color _textLight = Color(0xFF8A8A8A);

  /// Convert category key to human-readable display name
  static String _formatCategoryName(String category) {
    // Map of known category keys to display names
    const categoryNames = {
      'security_threats': 'Security',
      'security_sources': 'Security',
      'insecurity_soothing': 'Comfort',
      'vulnerability_safety': 'Vulnerability',
      'safety_expression': 'Safety',
      'values': 'Values',
      'future': 'Future',
      'family': 'Family',
      'money': 'Money',
      'communication': 'Communication',
      'emotional': 'Emotional',
      'conflict': 'Conflict',
      'intimacy': 'Intimacy',
      'lifestyle': 'Lifestyle',
      'entertainment': 'Entertainment',
      'social': 'Social',
      'daily_life': 'Daily Life',
    };

    final key = category.toLowerCase();
    if (categoryNames.containsKey(key)) {
      return categoryNames[key]!.toUpperCase();
    }
    // Fallback: convert snake_case to Title Case
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ')
        .toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _appreciation = widget.discovery.appreciation;
  }

  @override
  void didUpdateWidget(WorthDiscussingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.discovery.id != widget.discovery.id) {
      _appreciation = widget.discovery.appreciation;
    }
  }

  Future<void> _toggleAppreciation() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    HapticService().trigger(HapticType.light);

    final result = await UsProfileService().appreciateDiscovery(widget.discovery.id);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result != null) {
          _appreciation = result;
          widget.onAppreciationChanged?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header: Category + Partner Appreciation
            _buildHeader(),
            const SizedBox(height: 10),

            // Question Text
            if (widget.discovery.questionText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.discovery.questionText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                    height: 1.4,
                  ),
                ),
              ),

            // Answers
            _buildAnswers(),
            const SizedBox(height: 12),

            // Conversation Prompt
            if (widget.discovery.conversationPrompt.isNotEmpty)
              _buildConversationPrompt(),

            // Card Footer with Appreciate Button
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Category label
        if (widget.discovery.category != null)
          Text(
            _formatCategoryName(widget.discovery.category!),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: _textLight,
            ),
          )
        else
          const SizedBox.shrink(),

        // Partner appreciated indicator
        if (_appreciation.partnerAppreciated && !_appreciation.mutualAppreciation)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '\u2665 ',
                style: TextStyle(
                  fontSize: 11,
                  color: _emmaPink,
                ),
              ),
              Text(
                _appreciation.partnerAppreciatedLabel ?? 'Partner appreciates this',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _emmaPink,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAnswers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnswerRow(widget.user1Name, widget.discovery.user1Answer),
        const SizedBox(height: 6),
        _buildAnswerRow(widget.user2Name, widget.discovery.user2Answer),
      ],
    );
  }

  Widget _buildAnswerRow(String name, String answer) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$name:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _emmaPink,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            answer,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: _textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationPrompt() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: _accentGold.withOpacity(0.5),
            width: 2,
          ),
        ),
      ),
      child: Text(
        widget.discovery.conversationPrompt,
        style: const TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: _textMedium,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0x0F000000), // rgba(0,0,0,0.06)
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Appreciate button or mutual badge
          if (_appreciation.mutualAppreciation)
            _buildMutualBadge()
          else
            _buildAppreciateButton(),
        ],
      ),
    );
  }

  Widget _buildAppreciateButton() {
    final isAppreciated = _appreciation.userAppreciated;

    return GestureDetector(
      onTap: _isLoading ? null : _toggleAppreciation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isAppreciated ? _emmaPink : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAppreciated ? _emmaPink : _emmaPink.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isAppreciated ? Colors.white : _textMedium,
                  ),
                ),
              )
            else
              Text(
                isAppreciated ? '\u2665' : '\u2661',
                style: TextStyle(
                  fontSize: 15,
                  color: isAppreciated ? Colors.white : _textMedium,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              isAppreciated ? 'Appreciated' : 'Appreciate',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isAppreciated ? Colors.white : _textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMutualBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          '\u2665 ',
          style: TextStyle(
            fontSize: 12,
            color: _emmaPink,
          ),
        ),
        Text(
          'You both appreciate this',
          style: TextStyle(
            fontSize: 12,
            color: _emmaPink,
          ),
        ),
      ],
    );
  }
}
