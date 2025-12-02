import 'package:flutter/material.dart';
import 'package:togetherremind/theme/app_theme.dart';

/// Newspaper theme color palette
class NewspaperColors {
  static const Color background = Color(0xFFF0EDE8);
  static const Color surface = Color(0xFFFFFEF9);
  static const Color primary = Color(0xFF1A1A1A);
  static const Color secondary = Color(0xFF666666);
  static const Color tertiary = Color(0xFF999999);
  static const Color border = Color(0xFF1A1A1A);
  static const Color calloutBg = Color(0xFFF5F4EF);
}

/// Grayscale emoji widget for newspaper theme
class GrayscaleEmoji extends StatelessWidget {
  final String emoji;
  final double size;

  const GrayscaleEmoji({
    super.key,
    required this.emoji,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Colors.grey,
        BlendMode.saturation,
      ),
      child: Text(
        emoji,
        style: TextStyle(fontSize: size),
      ),
    );
  }
}

/// Newspaper masthead with double border
class NewspaperMasthead extends StatelessWidget {
  final String? date;
  final String title;
  final String? subtitle;

  const NewspaperMasthead({
    super.key,
    this.date,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: NewspaperColors.surface,
        border: Border(
          bottom: BorderSide(
            color: NewspaperColors.border,
            width: 3,
            style: BorderStyle.solid,
          ),
        ),
      ),
      child: Column(
        children: [
          if (date != null) ...[
            Text(
              date!.toUpperCase(),
              style: AppTheme.bodyFont.copyWith(
                fontSize: 10,
                letterSpacing: 3,
                color: NewspaperColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: AppTheme.headlineFont.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              letterSpacing: -1,
              height: 1,
              color: NewspaperColors.primary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!.toUpperCase(),
              style: AppTheme.bodyFont.copyWith(
                fontSize: 11,
                letterSpacing: 4,
                color: NewspaperColors.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Edition bar below masthead
class NewspaperEditionBar extends StatelessWidget {
  final String left;
  final String right;

  const NewspaperEditionBar({
    super.key,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: NewspaperColors.surface,
        border: Border(
          bottom: BorderSide(
            color: NewspaperColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            left.toUpperCase(),
            style: AppTheme.bodyFont.copyWith(
              fontSize: 10,
              letterSpacing: 1,
              color: NewspaperColors.primary,
            ),
          ),
          Text(
            right.toUpperCase(),
            style: AppTheme.bodyFont.copyWith(
              fontSize: 10,
              letterSpacing: 1,
              color: NewspaperColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Article header with kicker, headline, and deck
class NewspaperArticleHeader extends StatelessWidget {
  final String? kicker;
  final String headline;
  final String? deck;

  const NewspaperArticleHeader({
    super.key,
    this.kicker,
    required this.headline,
    this.deck,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFDDDDDD),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kicker != null) ...[
            Text(
              kicker!.toUpperCase(),
              style: AppTheme.bodyFont.copyWith(
                fontSize: 10,
                letterSpacing: 3,
                color: NewspaperColors.tertiary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            headline,
            style: AppTheme.headlineFont.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              height: 1.2,
              color: NewspaperColors.primary,
            ),
          ),
          if (deck != null) ...[
            const SizedBox(height: 12),
            Text(
              deck!,
              style: AppTheme.headlineFont.copyWith(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Color(0xFF555555),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Callout box with left border (e.g., "Editor's Note")
class NewspaperCalloutBox extends StatelessWidget {
  final String title;
  final String text;

  const NewspaperCalloutBox({
    super.key,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: NewspaperColors.calloutBg,
        border: Border(
          left: BorderSide(
            color: NewspaperColors.border,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTheme.bodyFont.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: NewspaperColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: AppTheme.headlineFont.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Color(0xFF555555),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary button with newspaper styling
class NewspaperPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const NewspaperPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: NewspaperColors.primary,
          foregroundColor: NewspaperColors.surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NewspaperColors.surface,
                ),
              )
            : Text(
                text.toUpperCase(),
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2,
                  color: NewspaperColors.surface,
                ),
              ),
      ),
    );
  }
}

/// Secondary button with outline
class NewspaperSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const NewspaperSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: NewspaperColors.primary,
          side: const BorderSide(
            color: NewspaperColors.border,
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
        child: Text(
          text,
          style: AppTheme.headlineFont.copyWith(
            fontSize: 13,
            letterSpacing: 1,
            color: NewspaperColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Text field with newspaper styling
class NewspaperTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const NewspaperTextField({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.keyboardType,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: AppTheme.bodyFont.copyWith(
              fontSize: 10,
              letterSpacing: 2,
              color: NewspaperColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          enabled: enabled,
          onSubmitted: onSubmitted,
          style: AppTheme.headlineFont.copyWith(
            fontSize: 18,
            color: NewspaperColors.primary,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTheme.headlineFont.copyWith(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: const Color(0xFFBBBBBB),
            ),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: NewspaperColors.border,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: NewspaperColors.border,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(
                color: NewspaperColors.border,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single OTP box for verification screen
class OtpBox extends StatelessWidget {
  final String? digit;
  final bool isActive;

  const OtpBox({
    super.key,
    this.digit,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 40 / 48, // Maintain original aspect ratio
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? NewspaperColors.calloutBg : NewspaperColors.surface,
          border: Border(
            top: const BorderSide(color: NewspaperColors.border, width: 1),
            left: const BorderSide(color: NewspaperColors.border, width: 1),
            right: const BorderSide(color: NewspaperColors.border, width: 1),
            bottom: const BorderSide(color: NewspaperColors.border, width: 2),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              digit ?? '-',
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: NewspaperColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Row of OTP boxes with hidden input
class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool enabled;

  const OtpInput({
    super.key,
    this.length = 8,
    this.onCompleted,
    this.enabled = true,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        children: [
          // Hidden text field
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              enabled: widget.enabled,
              onChanged: (value) {
                setState(() {});
                if (value.length == widget.length) {
                  widget.onCompleted?.call(value);
                }
              },
            ),
          ),
          // Visible OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              final digit = index < _controller.text.length
                  ? _controller.text[index]
                  : null;
              final isActive = index == _controller.text.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: OtpBox(
                  digit: digit,
                  isActive: isActive && _focusNode.hasFocus,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String get value => _controller.text;

  void clear() {
    _controller.clear();
    setState(() {});
  }
}

/// Newspaper-style tab row
class NewspaperTabRow extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onTabSelected;

  const NewspaperTabRow({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: NewspaperColors.border,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isActive = index == selectedIndex;
          final isLast = index == tabs.length - 1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected?.call(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isActive ? NewspaperColors.surface : NewspaperColors.calloutBg,
                  border: Border(
                    right: isLast
                        ? BorderSide.none
                        : const BorderSide(
                            color: NewspaperColors.border,
                            width: 1,
                          ),
                  ),
                ),
                child: Text(
                  tabs[index].toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: NewspaperColors.primary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Inverted code banner for remote pairing
class NewspaperCodeBanner extends StatelessWidget {
  final String label;
  final String code;
  final String? timer;

  const NewspaperCodeBanner({
    super.key,
    required this.label,
    required this.code,
    this.timer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: NewspaperColors.primary,
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.bodyFont.copyWith(
              fontSize: 9,
              letterSpacing: 3,
              color: NewspaperColors.surface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: const TextStyle(
              fontFamily: 'Courier New',
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: NewspaperColors.surface,
            ),
          ),
          if (timer != null) ...[
            const SizedBox(height: 8),
            Text(
              timer!,
              style: AppTheme.headlineFont.copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: NewspaperColors.surface.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Or divider
class NewspaperOrDivider extends StatelessWidget {
  const NewspaperOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: Color(0xFFDDDDDD), thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'OR',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 10,
                letterSpacing: 2,
                color: NewspaperColors.tertiary,
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: Color(0xFFDDDDDD), thickness: 1),
          ),
        ],
      ),
    );
  }
}

/// Sign in link row
class NewspaperSignInLink extends StatelessWidget {
  final String text;
  final String linkText;
  final VoidCallback? onTap;

  const NewspaperSignInLink({
    super.key,
    required this.text,
    required this.linkText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 13,
            color: NewspaperColors.secondary,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onTap,
          child: Text(
            linkText,
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NewspaperColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
