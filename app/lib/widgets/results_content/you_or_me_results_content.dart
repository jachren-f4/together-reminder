import 'package:flutter/material.dart';
import '../../models/base_session.dart';
import '../../models/you_or_me.dart';
import '../../services/you_or_me_service.dart';
import '../../services/storage_service.dart';
import '../../utils/logger.dart';

/// Results content widget for You or Me game
/// Shows agreement statistics and individual answer comparisons
class YouOrMeResultsContent extends StatefulWidget {
  final BaseSession session;

  const YouOrMeResultsContent({
    super.key,
    required this.session,
  });

  @override
  State<YouOrMeResultsContent> createState() => _YouOrMeResultsContentState();
}

class _YouOrMeResultsContentState extends State<YouOrMeResultsContent> {
  final YouOrMeService _service = YouOrMeService();
  final StorageService _storage = StorageService();
  Map<String, dynamic>? _results;
  bool _isLoadingPartnerSession = false;

  @override
  void initState() {
    super.initState();
    _loadPartnerSessionAndCalculateResults();
  }

  Future<void> _loadPartnerSessionAndCalculateResults() async {
    setState(() {
      _isLoadingPartnerSession = true;
    });

    try {
      final session = widget.session as YouOrMeSession;
      final partner = _storage.getPartner();

      if (partner == null) {
        // If no partner, just use current session
        setState(() {
          _results = _service.calculateResultsFromDualSessions(session, null);
          _isLoadingPartnerSession = false;
        });
        return;
      }

      // Extract timestamp from current session ID
      final sessionParts = session.id.split('_');
      if (sessionParts.length < 3) {
        Logger.error('Invalid session ID format: ${session.id}', service: 'you_or_me');
        setState(() {
          _results = _service.calculateResultsFromDualSessions(session, null);
          _isLoadingPartnerSession = false;
        });
        return;
      }
      final timestamp = sessionParts.last;

      // Construct partner's session ID
      final partnerSessionId = 'youorme_${partner.pushToken}_$timestamp';

      // Fetch the partner's session
      final partnerSession = await _service.getSession(
        partnerSessionId,
        forceRefresh: true,
      );

      setState(() {
        _results = _service.calculateResultsFromDualSessions(session, partnerSession);
        _isLoadingPartnerSession = false;
      });
    } catch (e) {
      Logger.error('Error loading partner session', error: e, service: 'you_or_me');
      setState(() {
        final session = widget.session as YouOrMeSession;
        _results = _service.calculateResultsFromDualSessions(session, null);
        _isLoadingPartnerSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (_isLoadingPartnerSession || _results == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final totalQuestions = _results!['totalQuestions'] as int;
    final agreements = _results!['agreements'] as int;
    final disagreements = _results!['disagreements'] as int;
    final agreementPercentage = _results!['agreementPercentage'] as int;
    final comparisons = _results!['comparisons'] as List<Map<String, dynamic>>;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'You or Me?',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'See how your perspectives compare!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 32),

            // Agreement stats
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFD),
                border: Border.all(color: const Color(0xFFF0F0F0), width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    '$agreementPercentage%',
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Agreement',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatChip(
                        '$agreements/$totalQuestions',
                        'Agreed',
                        Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _buildStatChip(
                        '$disagreements/$totalQuestions',
                        'Different',
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Individual answers header
            Text(
              'Your Answers',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Answer comparisons
            ...comparisons.map((comparison) {
              final question = comparison['question'] as YouOrMeQuestion;
              final userAnswer = comparison['userAnswer'] as String?;
              final partnerAnswer = comparison['partnerAnswer'] as String?;
              final agreed = comparison['agreed'] as bool;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildComparisonCard(
                  question: question,
                  userAnswer: userAnswer,
                  partnerAnswer: partnerAnswer,
                  agreed: agreed,
                  userName: user?.name ?? 'You',
                  partnerName: partner?.name ?? 'Partner',
                ),
              );
            }),

            const SizedBox(height: 16),

            // Done button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color.fromRGBO(
                color.red,
                color.green,
                color.blue,
                1.0,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color.fromRGBO(
                color.red,
                color.green,
                color.blue,
                1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard({
    required YouOrMeQuestion question,
    required String? userAnswer,
    required String? partnerAnswer,
    required bool agreed,
    required String userName,
    required String partnerName,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFD),
        border: Border.all(
          color: agreed ? Colors.green.withOpacity(0.3) : const Color(0xFFF0F0F0),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (agreed)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              if (agreed) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.prompt,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6E6E6E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question.content,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Answers
          Row(
            children: [
              Expanded(
                child: _buildAnswerBadge(
                  label: userName,
                  answer: userAnswer,
                  isUser: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnswerBadge(
                  label: partnerName,
                  answer: partnerAnswer,
                  isUser: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerBadge({
    required String label,
    required String? answer,
    required bool isUser,
  }) {
    String answerText;
    switch (answer) {
      case 'me':
        answerText = isUser ? 'Me' : 'You';
        break;
      case 'partner':
        answerText = isUser ? 'Partner' : 'Me';
        break;
      case 'neither':
        answerText = 'Neither';
        break;
      case 'both':
        answerText = 'Both';
        break;
      default:
        answerText = '—';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6E6E6E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            answerText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}
