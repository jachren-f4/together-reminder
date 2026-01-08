import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/us2_theme.dart';
import '../models/magnet_collection.dart';
import '../services/magnet_service.dart';
import '../widgets/brand/us2/us2_connection_bar.dart';

/// Collection View screen - matches mockup exactly
/// See: mockups/magnet-collection/collection-view.html
class MagnetCollectionScreen extends StatefulWidget {
  const MagnetCollectionScreen({super.key});

  @override
  State<MagnetCollectionScreen> createState() => _MagnetCollectionScreenState();
}

class _MagnetCollectionScreenState extends State<MagnetCollectionScreen> {
  final MagnetService _magnetService = MagnetService();
  MagnetCollection? _collection;
  bool _isLoading = true;

  // Colors from mockup CSS variables
  static const Color cream = Color(0xFFFFF8F0);
  static const Color beige = Color(0xFFF5E6D8);
  static const Color textDark = Color(0xFF3A3A3A);
  static const Color textLight = Color(0xFF707070);
  static const Color primaryPink = Color(0xFFFF5E62);
  static const Color goldBorder = Color(0xFFC9A875);

  /// Format number with comma separators (e.g., 2500 -> "2,500")
  String _formatNumber(int number) {
    if (number < 1000) return number.toString();
    final String str = number.toString();
    final int len = str.length;
    return '${str.substring(0, len - 3)},${str.substring(len - 3)}';
  }

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    setState(() => _isLoading = true);

    final cached = _magnetService.getCachedCollection();
    if (cached != null) {
      setState(() {
        _collection = cached;
        _isLoading = false;
      });
    }

    final collection = await _magnetService.fetchAndSync();
    if (mounted && collection != null) {
      setState(() {
        _collection = collection;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: Us2Theme.backgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      child: _buildHeader(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildProgressSection(),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _buildMagnetGrid(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Header: back button, "Our Collection" title, count badge
  Widget _buildHeader() {
    final unlockedCount = _collection?.unlockedCount ?? 0;

    return Row(
      children: [
        // Back button - cream circle
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cream,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryPink.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: primaryPink, size: 18),
          ),
        ),
        const SizedBox(width: 15),
        // Title - Playfair Display italic
        Text(
          'Our Collection',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: textDark,
          ),
        ),
        const Spacer(),
        // Count badge - gradient background
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '$unlockedCount/30',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Progress section - cream card with next magnet preview
  Widget _buildProgressSection() {
    final nextMagnetId = _collection?.nextMagnetId ?? 1;
    final currentLp = _collection?.currentLp ?? 0;
    final allUnlocked = _collection?.allUnlocked ?? false;

    // Calculate tier-based progress (fills up, resets after each unlock)
    final prevThreshold = (_collection?.unlockedCount ?? 0) > 0
        ? Us2ConnectionBar.getCumulativeLpForMagnet(_collection!.unlockedCount)
        : 0;
    final nextThreshold = Us2ConnectionBar.getCumulativeLpForMagnet(nextMagnetId);
    final lpNeededForTier = nextThreshold - prevThreshold;
    final lpInCurrentTier = currentLp - prevThreshold;
    final progress = lpNeededForTier > 0 ? (lpInCurrentTier / lpNeededForTier).clamp(0.0, 1.0) : 0.0;

    final nextMagnetName = MagnetCollection.getMagnetName(nextMagnetId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: beige, width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryPink.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Next magnet preview image
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: goldBorder, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildMagnetImage(nextMagnetId),
                ),
              ),
              const SizedBox(width: 14),
              // Next magnet info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT DESTINATION',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: textLight,
                      ),
                    ),
                    Text(
                      allUnlocked ? 'All Collected!' : nextMagnetName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    Text(
                      allUnlocked ? 'Congratulations!' : '${_formatNumber(currentLp)} LP',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryPink,
                      ),
                    ),
                    if (!allUnlocked)
                      Text(
                        'Unlock at ${_formatNumber(nextThreshold)} LP',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textLight,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: beige,
              borderRadius: BorderRadius.circular(5),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fillWidth = constraints.maxWidth * (allUnlocked ? 1.0 : progress);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: fillWidth,
                      height: 10,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Magnet grid - 3 columns, Polaroid style
  Widget _buildMagnetGrid() {
    final unlockedCount = _collection?.unlockedCount ?? 0;
    final nextMagnetId = _collection?.nextMagnetId ?? 1;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85, // Taller for Polaroid bottom padding
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        final magnetId = index + 1;
        final isUnlocked = magnetId <= unlockedCount;
        final isCurrent = magnetId == nextMagnetId;

        return _MagnetTile(
          magnetId: magnetId,
          isUnlocked: isUnlocked,
          isCurrent: isCurrent,
          onTap: isUnlocked ? () => _showMagnetDetail(magnetId) : null,
        );
      },
    );
  }

  Widget _buildMagnetImage(int magnetId) {
    final assetPath = MagnetCollection.getMagnetAssetPath(magnetId);
    final emoji = Us2ConnectionBar.getMagnetEmoji(magnetId);

    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFFFD1C1),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        );
      },
    );
  }

  void _showMagnetDetail(int magnetId) {
    final name = MagnetCollection.getMagnetName(magnetId);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Magnet image
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildMagnetImage(magnetId),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Magnet #$magnetId',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textLight,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: primaryPink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Polaroid-style magnet tile - matches mockup CSS
class _MagnetTile extends StatelessWidget {
  final int magnetId;
  final bool isUnlocked;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _MagnetTile({
    required this.magnetId,
    required this.isUnlocked,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Polaroid style per mockup: white bg, padding, extra bottom padding
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 24),
        decoration: BoxDecoration(
          color: isUnlocked ? Colors.white : const Color(0xFFE8E0D8),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          // Current/next magnet gets golden highlight
          border: isCurrent
              ? Border.all(color: const Color(0xFFC9A875), width: 3)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image with grayscale for locked
              ColorFiltered(
                colorFilter: isUnlocked
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                    : const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                child: Opacity(
                  opacity: isUnlocked ? 1.0 : 0.4,
                  child: _buildMagnetImage(),
                ),
              ),
              // Lock overlay for locked magnets
              if (!isUnlocked)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Text('🔒', style: TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMagnetImage() {
    final assetPath = MagnetCollection.getMagnetAssetPath(magnetId);
    final emoji = Us2ConnectionBar.getMagnetEmoji(magnetId);

    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFFFD1C1),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        );
      },
    );
  }
}
