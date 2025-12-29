import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:togetherremind/config/journal_fonts.dart';
import 'package:togetherremind/models/journal_entry.dart';
import 'package:togetherremind/models/quiz_answer_detail.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/journal_service.dart';
import 'package:togetherremind/widgets/journal/quiz_answer_card.dart';

/// Bottom sheet showing detailed information for a journal entry.
///
/// Displays different content based on entry type:
/// - Quizzes: Question-by-question comparison
/// - You or Me: Answer comparisons
/// - Linked/Word Search: Words solved, scores, stats
/// - Steps Together: Step counts and goal progress
class JournalDetailSheet extends StatefulWidget {
  final JournalEntry entry;

  const JournalDetailSheet({
    super.key,
    required this.entry,
  });

  /// Show the detail sheet as a modal bottom sheet
  static Future<void> show(BuildContext context, JournalEntry entry) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalDetailSheet(entry: entry),
    );
  }

  @override
  State<JournalDetailSheet> createState() => _JournalDetailSheetState();
}

class _JournalDetailSheetState extends State<JournalDetailSheet> {
  double _dragOffset = 0;
  String? _partnerName;

  @override
  void initState() {
    super.initState();
    _partnerName = StorageService().getPartner()?.name ?? 'Partner';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dy);
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset > 80) {
          Navigator.pop(context);
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragOffset.clamp(0, double.infinity)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6D8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          // Type emoji
          Text(
            widget.entry.typeEmoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            widget.entry.title,
            style: JournalFonts.sheetTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Type name
          Text(
            widget.entry.typeName,
            style: JournalFonts.polaroidType,
          ),
          const SizedBox(height: 8),
          // Date/time
          Text(
            DateFormat('EEEE, MMM d • h:mm a').format(widget.entry.completedAt.toLocal()),
            style: JournalFonts.insightDetail,
          ),
          const SizedBox(height: 12),
          // Summary badge
          _buildSummaryBadge(),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge() {
    String text;
    Color bgColor;

    if (widget.entry.isGame) {
      // Linked or Word Search
      final isTie = widget.entry.userScore == widget.entry.partnerScore;
      if (isTie) {
        text = '🤝 Perfect tie!';
        bgColor = const Color(0xFFFFF3E0);
      } else {
        final didWin = widget.entry.userScore > widget.entry.partnerScore;
        text = didWin ? '🏆 You won!' : '🥈 Close match!';
        bgColor = didWin ? const Color(0xFFFFF9C4) : const Color(0xFFE3F2FD);
      }
    } else if (widget.entry.isSteps) {
      final percentage = widget.entry.stepGoal > 0
          ? ((widget.entry.combinedSteps / widget.entry.stepGoal) * 100).round()
          : 0;
      if (percentage >= 100) {
        text = '🎉 Goal achieved!';
        bgColor = const Color(0xFFE8F5E9);
      } else {
        text = '👟 $percentage% of goal';
        bgColor = const Color(0xFFF3E5F5);
      }
    } else {
      // Quiz or You or Me
      final total = widget.entry.alignedCount + widget.entry.differentCount;
      final percentage = total > 0
          ? ((widget.entry.alignedCount / total) * 100).round()
          : 0;
      if (percentage == 100) {
        text = '💫 Perfectly aligned!';
        bgColor = const Color(0xFFFCE4EC);
      } else if (percentage == 0) {
        text = '✨ Beautifully different!';
        bgColor = const Color(0xFFE3F2FD);
      } else {
        text = '💕 $percentage% aligned';
        bgColor = const Color(0xFFFCE4EC);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2D2D2D),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (widget.entry.type) {
      case JournalEntryType.linked:
        return _buildLinkedDetails();
      case JournalEntryType.wordSearch:
        return _buildWordSearchDetails();
      case JournalEntryType.stepsTogether:
        return _buildStepsDetails();
      case JournalEntryType.youOrMe:
        return _buildYouOrMeDetails();
      default:
        return _buildQuizDetails();
    }
  }

  // ============================================
  // Quiz Details (Classic, Affirmation, Welcome, You or Me)
  // ============================================

  Widget _buildQuizDetails() {
    return _buildQuizDetailsWithFuture();
  }

  Widget _buildYouOrMeDetails() {
    return _buildQuizDetailsWithFuture();
  }

  /// Shared implementation for all quiz-type details using FutureBuilder.
  Widget _buildQuizDetailsWithFuture() {
    final contentId = widget.entry.contentId;
    if (contentId == null || contentId.isEmpty) {
      return _buildQuizFallback();
    }

    return FutureBuilder<QuizDetailsResponse?>(
      future: JournalService().getQuizDetails(contentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _buildQuizFallback();
        }

        final details = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Your Answers'),
              const SizedBox(height: 12),
              ...details.answers.map((answer) => QuizAnswerCard(
                    answer: answer,
                    questionNumber: answer.questionIndex + 1,
                    partnerName: _partnerName ?? 'Partner',
                  )),
            ],
          ),
        );
      },
    );
  }

  /// Fallback view when quiz details can't be loaded from API.
  Widget _buildQuizFallback() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Answer Comparison'),
          const SizedBox(height: 12),
          _buildQuizSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildQuizSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn('Aligned', '${widget.entry.alignedCount}', const Color(0xFF4CAF50)),
              Container(width: 1, height: 40, color: const Color(0xFFE0E0E0)),
              _buildStatColumn('Different', '${widget.entry.differentCount}', const Color(0xFFFF9800)),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // Linked Details
  // ============================================

  Widget _buildLinkedDetails() {
    // Use data from JournalEntry directly (already fetched from API)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Final Score'),
          const SizedBox(height: 12),
          _buildScoreCards(
            widget.entry.userScore,
            widget.entry.partnerScore,
            'words found',
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Game Stats'),
          const SizedBox(height: 12),
          _buildStatsRow(
            'Total Turns',
            '${widget.entry.totalTurns}',
          ),
          const SizedBox(height: 8),
          _buildStatsRow(
            'Hints Used',
            'You: ${widget.entry.userHintsUsed} • $_partnerName: ${widget.entry.partnerHintsUsed}',
          ),
        ],
      ),
    );
  }

  // ============================================
  // Word Search Details
  // ============================================

  Widget _buildWordSearchDetails() {
    // Use data from JournalEntry directly (already fetched from API)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Final Score'),
          const SizedBox(height: 12),
          _buildScoreCards(
            widget.entry.userScore,
            widget.entry.partnerScore,
            'words found',
          ),
          const SizedBox(height: 16),
          _buildScoreCards(
            widget.entry.userPoints,
            widget.entry.partnerPoints,
            'points',
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Game Stats'),
          const SizedBox(height: 12),
          _buildStatsRow(
            'Total Turns',
            '${widget.entry.totalTurns}',
          ),
          const SizedBox(height: 8),
          _buildStatsRow(
            'Hints Used',
            'You: ${widget.entry.userHintsUsed} • $_partnerName: ${widget.entry.partnerHintsUsed}',
          ),
        ],
      ),
    );
  }

  // ============================================
  // Steps Together Details
  // ============================================

  Widget _buildStepsDetails() {
    final percentage = widget.entry.stepGoal > 0
        ? ((widget.entry.combinedSteps / widget.entry.stepGoal) * 100).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Steps Progress'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '${widget.entry.combinedSteps}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
                Text(
                  'of ${widget.entry.stepGoal} combined steps',
                  style: JournalFonts.insightDetail,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$percentage% of goal',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // Shared Components
  // ============================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: JournalFonts.sectionTitle,
    );
  }

  Widget _buildScoreCards(int userScore, int partnerScore, String unit) {
    return Row(
      children: [
        Expanded(
          child: _buildScoreCard('You', userScore, unit, true),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildScoreCard(_partnerName ?? 'Partner', partnerScore, unit, false),
        ),
      ],
    );
  }

  Widget _buildScoreCard(String label, int score, String unit, bool isUser) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFE3F2FD) : const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D2D),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: JournalFonts.insightHeadline,
          ),
          Text(
            value,
            style: JournalFonts.insightDetail,
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Widget _buildDataUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Details unavailable',
              style: JournalFonts.emptyStateHeader,
            ),
            const SizedBox(height: 8),
            Text(
              'The detailed data for this entry could not be loaded.',
              style: JournalFonts.emptyStateDescription,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
