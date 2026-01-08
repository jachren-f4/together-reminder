/**
 * Magnet Collection System
 *
 * Main exports for the magnet collection feature.
 */

export {
  TOTAL_MAGNETS,
  MAGNET_THRESHOLDS,
  getLPRequirement,
  getCumulativeLPForMagnet,
  getUnlockedMagnetCount,
  getMagnetProgress,
  detectUnlock,
  detectAllUnlocks,
  type MagnetProgress,
} from './calculator';

export {
  BATCH_SIZE,
  COOLDOWN_HOURS,
  getCooldownStatus,
  recordActivityPlay,
  getAllCooldownStatuses,
  resetCooldown,
  resetAllCooldowns,
  type ActivityType,
  type CooldownStatus,
  type CooldownEntry,
  type CooldownsMap,
} from './cooldowns';
