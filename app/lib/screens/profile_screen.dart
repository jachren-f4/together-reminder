import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/love_point_service.dart';
import '../theme/app_theme.dart';
import '../models/love_point_transaction.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final stats = LovePointService.getStats();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Your Progress',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Together with ${partner?.name ?? 'your partner'}',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // LP Counter Card
              _buildLovePointsCard(stats),

              const SizedBox(height: 20),

              // Current Arena Card
              _buildCurrentArenaCard(stats),

              const SizedBox(height: 20),

              // Progress to Next Tier
              _buildProgressCard(stats),

              const SizedBox(height: 20),

              // Recent Activity
              _buildRecentActivitySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLovePointsCard(Map<String, dynamic> stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Column(
        children: [
          const Text(
            '💰',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            '${stats['total']} LP',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlack,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Love Points',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),

          // Floor Protection Indicator
          if (stats['floor'] > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'Protected at ${stats['floor']} LP',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentArenaCard(Map<String, dynamic> stats) {
    final arena = stats['currentArena'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Arena',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                arena['emoji'],
                style: const TextStyle(fontSize: 56),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arena['name'],
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlack,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tier ${stats['tier']} of 5',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(Map<String, dynamic> stats) {
    final nextArena = stats['nextArena'];
    final progress = stats['progressToNext'];

    if (nextArena == null) {
      // Max tier reached
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderLight, width: 1),
        ),
        child: Center(
          child: Column(
            children: [
              const Text('👑', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'Max Tier Reached!',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlack,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentLP = stats['total'];
    final nextTierLP = nextArena['min'];
    final remaining = nextTierLP - currentLP;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next Arena',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$remaining LP to go',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppTheme.borderLight,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryBlack,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Text(
                nextArena['emoji'],
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextArena['name'],
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlack,
                    ),
                  ),
                  Text(
                    'Unlocks at $nextTierLP LP',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final transactions = _storage.getRecentTransactions(limit: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: AppTheme.bodyFont.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),

        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight, width: 1),
            ),
            child: Center(
              child: Text(
                'No activity yet',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          )
        else
          ...transactions.map((tx) => _buildTransactionItem(tx)).toList(),
      ],
    );
  }

  Widget _buildTransactionItem(LovePointTransaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: transaction.amount > 0
                  ? AppTheme.borderLight
                  : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                transaction.amount > 0 ? '+' : '-',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: transaction.amount > 0
                      ? AppTheme.primaryBlack
                      : Colors.red,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.displayReason,
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlack,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimestamp(transaction.timestamp),
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.amount > 0 ? '+' : ''}${transaction.amount} LP',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: transaction.amount > 0
                  ? AppTheme.primaryBlack
                  : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
