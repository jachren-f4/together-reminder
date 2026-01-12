import 'package:flutter/material.dart';
import '../config/brand/us2_theme.dart';
import '../services/storage_service.dart';
import '../models/steps_data.dart';

/// Screen showing 7-day step history with streaks and insights.
class StepsWeekHistoryScreen extends StatefulWidget {
  const StepsWeekHistoryScreen({super.key});

  @override
  State<StepsWeekHistoryScreen> createState() => _StepsWeekHistoryScreenState();
}

class _StepsWeekHistoryScreenState extends State<StepsWeekHistoryScreen> {
  final StorageService _storage = StorageService();
  late List<_DayData> _weekData;
  int _streak = 0;
  int _totalSteps = 0;
  int _totalLP = 0;
  int _goalsHit = 0;
  _DayData? _bestDay;

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  void _loadWeekData() {
    final now = DateTime.now();
    _weekData = [];

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final stepsDay = _storage.getStepsDay(dateKey);

      final dayData = _DayData(
        date: date,
        dateKey: dateKey,
        dayName: _getDayName(date, i),
        stepsDay: stepsDay,
        isToday: i == 0,
      );

      _weekData.add(dayData);

      if (stepsDay != null) {
        _totalSteps += stepsDay.combinedSteps;
        if (stepsDay.claimed || i == 0) {
          _totalLP += stepsDay.earnedLP;
        }
        if (stepsDay.combinedSteps >= 10000) {
          _goalsHit++;
        }
        if (_bestDay == null || stepsDay.combinedSteps > (_bestDay!.stepsDay?.combinedSteps ?? 0)) {
          _bestDay = dayData;
        }
      }
    }

    // Calculate streak (consecutive days >= 10K from today)
    _streak = 0;
    for (final day in _weekData) {
      if (day.stepsDay != null && day.stepsDay!.combinedSteps >= 10000) {
        _streak++;
      } else if (!day.isToday) {
        break;
      }
    }
  }

  String _getDayName(DateTime date, int daysAgo) {
    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[date.weekday % 7];
  }

  @override
  Widget build(BuildContext context) {
    final partner = _storage.getPartner();

    return Scaffold(
      backgroundColor: Us2Theme.bgGradientEnd,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Us2Theme.textDark, size: 20),
            ),
          ),
        ),
        title: const Text(
          'This Week',
          style: TextStyle(
            fontFamily: Us2Theme.fontHeading,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Us2Theme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Streak card
                _buildStreakCard(),
                const SizedBox(height: 16),

                // Week summary
                _buildWeekSummaryCard(),
                const SizedBox(height: 16),

                // Daily breakdown
                _buildDailyBreakdownCard(partner?.name ?? 'Partner'),
                const SizedBox(height: 16),

                // Best day
                if (_bestDay != null) _buildBestDayCard(_bestDay!, partner?.name ?? 'Partner'),
                const SizedBox(height: 16),

                // Insights
                _buildInsightsCard(partner?.name ?? 'Partner'),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: Us2Theme.accentGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            '$_streak',
            style: const TextStyle(
              fontFamily: Us2Theme.fontHeading,
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Text(
            'Day Streak',
            style: TextStyle(
              fontFamily: Us2Theme.fontBody,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _streak > 0
                ? 'Keep it up! You\'re on fire!'
                : 'Walk 10K+ steps together to start a streak!',
            style: TextStyle(
              fontFamily: Us2Theme.fontBody,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSummaryCard() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: 6));
    final dateRange = '${_formatShortDate(weekStart)} - ${_formatShortDate(now)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Week Summary',
                style: TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                ),
              ),
              Text(
                dateRange,
                style: const TextStyle(
                  fontFamily: Us2Theme.fontBody,
                  fontSize: 12,
                  color: Us2Theme.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatBox(_formatNumber(_totalSteps), 'Total Steps'),
              const SizedBox(width: 12),
              _buildStatBox('$_totalLP LP', 'Earned'),
              const SizedBox(width: 12),
              _buildStatBox('$_goalsHit/7', 'Goals Hit'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: Us2Theme.fontHeading,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Us2Theme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: Us2Theme.fontBody,
                fontSize: 11,
                color: Us2Theme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBreakdownCard(String partnerName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Breakdown',
            style: TextStyle(
              fontFamily: Us2Theme.fontHeading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 16),
          ..._weekData.map((day) => _buildDayRow(day)),
        ],
      ),
    );
  }

  Widget _buildDayRow(_DayData day) {
    final steps = day.stepsDay?.combinedSteps ?? 0;
    final lp = day.stepsDay?.earnedLP ?? 0;
    final isMissed = steps < 10000 && !day.isToday;
    final isMax = steps >= 20000;
    final isSuccess = steps >= 10000 && !isMax;

    String emoji;
    Color bgColor;
    if (day.isToday) {
      emoji = '';
      bgColor = Us2Theme.gradientAccentStart;
    } else if (isMax) {
      emoji = '';
      bgColor = const Color(0xFFFFB347);
    } else if (isSuccess) {
      emoji = '';
      bgColor = const Color(0xFF4CAF50);
    } else if (steps > 0) {
      emoji = '';
      bgColor = const Color(0xFFFFF3E0);
    } else {
      emoji = '';
      bgColor = const Color(0xFFF5F5F5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: day.isToday
            ? const Color(0xFFFFF0EB).withValues(alpha: 0.5)
            : isMissed
                ? Colors.grey.shade50
                : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: day.isToday
            ? Border.all(color: Us2Theme.gradientAccentStart.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        children: [
          // Status circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 16),

          // Day info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      day.dayName,
                      style: TextStyle(
                        fontFamily: Us2Theme.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isMissed ? Us2Theme.textLight : Us2Theme.textDark,
                      ),
                    ),
                    if (!day.isToday) ...[
                      const SizedBox(width: 4),
                      Text(
                        _formatShortDate(day.date),
                        style: const TextStyle(
                          fontFamily: Us2Theme.fontBody,
                          fontSize: 12,
                          color: Us2Theme.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  steps > 0
                      ? '${_formatNumber(steps)} steps${steps >= 10000 ? ' · ${_getTierName(steps)} tier' : ' · Below threshold'}'
                      : 'No data synced',
                  style: TextStyle(
                    fontFamily: Us2Theme.fontBody,
                    fontSize: 12,
                    color: isMissed ? Us2Theme.textLight : Us2Theme.textMedium,
                  ),
                ),
              ],
            ),
          ),

          // LP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lp > 0 ? '+$lp' : '0',
                style: TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: day.isToday
                      ? Us2Theme.gradientAccentStart
                      : isMax
                          ? const Color(0xFFFF8C00)
                          : isSuccess
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFCCCCCC),
                ),
              ),
              Text(
                day.isToday
                    ? 'pending'
                    : lp > 0
                        ? 'earned'
                        : 'missed',
                style: const TextStyle(
                  fontFamily: Us2Theme.fontBody,
                  fontSize: 10,
                  color: Us2Theme.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBestDayCard(_DayData bestDay, String partnerName) {
    final steps = bestDay.stepsDay?.combinedSteps ?? 0;
    final userSteps = bestDay.stepsDay?.userSteps ?? 0;
    final partnerSteps = bestDay.stepsDay?.partnerSteps ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1AFFB347), Color(0x1AFFD89B)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4DFFB347)),
      ),
      child: Column(
        children: [
          const Text(
            ' Best Day This Week',
            style: TextStyle(
              fontFamily: Us2Theme.fontBody,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF8C00),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatNumber(steps),
            style: const TextStyle(
              fontFamily: Us2Theme.fontHeading,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Us2Theme.textDark,
            ),
          ),
          Text(
            'Steps',
            style: const TextStyle(
              fontFamily: Us2Theme.fontBody,
              fontSize: 14,
              color: Us2Theme.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${bestDay.dayName} · You: ${_formatNumber(userSteps)} · $partnerName: ${_formatNumber(partnerSteps)}',
            style: const TextStyle(
              fontFamily: Us2Theme.fontBody,
              fontSize: 12,
              color: Us2Theme.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(String partnerName) {
    // Calculate some insights
    int userTotal = 0;
    int partnerTotal = 0;
    int daysWithData = 0;

    for (final day in _weekData) {
      if (day.stepsDay != null && day.stepsDay!.combinedSteps > 0) {
        userTotal += day.stepsDay!.userSteps;
        partnerTotal += day.stepsDay!.partnerSteps;
        daysWithData++;
      }
    }

    final userAvg = daysWithData > 0 ? (userTotal / daysWithData).round() : 0;
    final partnerAvg = daysWithData > 0 ? (partnerTotal / daysWithData).round() : 0;
    final missedDays = _weekData.where((d) => !d.isToday && (d.stepsDay?.combinedSteps ?? 0) < 10000).length;
    final potentialLP = missedDays * 15; // Minimum LP per day

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'Insights',
                style: TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (daysWithData > 0)
            _buildInsightRow(
              '',
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: Us2Theme.fontBody,
                    fontSize: 13,
                    color: Us2Theme.textMedium,
                  ),
                  children: [
                    TextSpan(
                      text: partnerName,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Us2Theme.textDark),
                    ),
                    TextSpan(text: ' averaged ${_formatNumber(partnerAvg)} steps. You averaged ${_formatNumber(userAvg)}. '),
                    TextSpan(
                      text: userAvg > partnerAvg ? 'Great balance!' : 'Keep it up!',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          if (missedDays > 0)
            _buildInsightRow(
              '',
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: Us2Theme.fontBody,
                    fontSize: 13,
                    color: Us2Theme.textMedium,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Tip: ',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Us2Theme.textDark),
                    ),
                    TextSpan(text: 'You missed $missedDays days below threshold. Hitting 10K those days would have earned you '),
                    TextSpan(
                      text: '+$potentialLP LP',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Us2Theme.gradientAccentStart,
                      ),
                    ),
                    const TextSpan(text: '!'),
                  ],
                ),
              ),
            ),

          if (_streak >= 3)
            _buildInsightRow(
              '',
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: Us2Theme.fontBody,
                    fontSize: 13,
                    color: Us2Theme.textMedium,
                  ),
                  children: [
                    TextSpan(
                      text: '$_streak day streak of 10K+ together! ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Us2Theme.gradientAccentStart,
                      ),
                    ),
                    const TextSpan(text: 'Keep it going!'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String emoji, Widget text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: text),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return number.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return number.toString();
  }

  String _formatShortDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _getTierName(int steps) {
    if (steps >= 20000) return '20K';
    if (steps >= 18000) return '18K';
    if (steps >= 16000) return '16K';
    if (steps >= 14000) return '14K';
    if (steps >= 12000) return '12K';
    if (steps >= 10000) return '10K';
    return '<10K';
  }
}

class _DayData {
  final DateTime date;
  final String dateKey;
  final String dayName;
  final StepsDay? stepsDay;
  final bool isToday;

  _DayData({
    required this.date,
    required this.dateKey,
    required this.dayName,
    required this.stepsDay,
    required this.isToday,
  });
}
