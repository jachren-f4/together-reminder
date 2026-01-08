/**
 * Magnet Collection API
 *
 * GET /api/magnets - Get magnet collection status and cooldowns
 *
 * Returns:
 * - Magnet progress (unlocked count, progress to next)
 * - Cooldown status for all activity types
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { getCouple } from '@/lib/couple/utils';
import { getMagnetProgress, getAllCooldownStatuses } from '@/lib/magnets';
import { NextResponse } from 'next/server';

export interface MagnetCollectionResponse {
  // Magnet progress
  unlockedCount: number;
  nextMagnetId: number | null;
  currentLp: number;
  lpForNextMagnet: number;
  lpProgressToNext: number;
  progressPercent: number;
  totalMagnets: number;
  allUnlocked: boolean;

  // Cooldowns per activity type
  cooldowns: {
    classic_quiz: CooldownInfo;
    affirmation_quiz: CooldownInfo;
    you_or_me: CooldownInfo;
    linked: CooldownInfo;
    wordsearch: CooldownInfo;
  };
}

interface CooldownInfo {
  canPlay: boolean;
  remainingInBatch: number;
  cooldownEndsAt: string | null;
  cooldownRemainingMs: number | null;
}

export const GET = withAuthOrDevBypass(async (req, userId) => {
  try {
    // 1. Get couple info (includes total_lp)
    const couple = await getCouple(userId);

    if (!couple) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    // 2. Calculate magnet progress from LP
    const magnetProgress = getMagnetProgress(couple.totalLp);

    // 3. Get cooldown status for all activity types
    const cooldowns = await getAllCooldownStatuses(couple.coupleId);

    // 4. Format cooldowns for response
    const cooldownsFormatted: Record<string, CooldownInfo> = {};
    for (const [activityType, status] of Object.entries(cooldowns)) {
      cooldownsFormatted[activityType] = {
        canPlay: status.canPlay,
        remainingInBatch: status.remainingInBatch,
        cooldownEndsAt: status.cooldownEndsAt?.toISOString() ?? null,
        cooldownRemainingMs: status.cooldownRemainingMs,
      };
    }

    const response: MagnetCollectionResponse = {
      // Magnet progress
      unlockedCount: magnetProgress.unlockedCount,
      nextMagnetId: magnetProgress.nextMagnetId,
      currentLp: magnetProgress.currentLp,
      lpForNextMagnet: magnetProgress.lpForNextMagnet,
      lpProgressToNext: magnetProgress.lpProgressToNext,
      progressPercent: magnetProgress.progressPercent,
      totalMagnets: magnetProgress.totalMagnets,
      allUnlocked: magnetProgress.allUnlocked,

      // Cooldowns
      cooldowns: cooldownsFormatted as MagnetCollectionResponse['cooldowns'],
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Error fetching magnet collection:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});
