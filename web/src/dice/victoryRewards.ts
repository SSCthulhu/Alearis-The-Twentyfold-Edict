import type { RunState } from '../core/RunState';
import type { FinalBossId, RelicBand } from '../core/types';

export interface VictoryRewardRoll {
  roll: number;
  band: RelicBand;
}

export interface FinalBossRoll {
  roll: number;
  bossId: FinalBossId;
}

export function relicBandForVictoryRoll(roll: number): RelicBand {
  if (roll <= 8) return 'SURVIVAL';
  if (roll <= 14) return 'CORE';
  return 'GREED_DAMAGE';
}

export function rollVictoryReward(run: RunState): VictoryRewardRoll {
  const roll = run.roll('victory_reward');
  return {
    roll,
    band: relicBandForVictoryRoll(roll),
  };
}

export function finalBossForRoll(roll: number): FinalBossId {
  if (roll <= 1) return 'a';
  if (roll <= 7) return 'b';
  if (roll <= 13) return 'c';
  if (roll <= 19) return 'd';
  return 'e';
}

export function rollFinalBoss(run: RunState): FinalBossRoll {
  const roll = run.roll('final_boss');
  const bossId = finalBossForRoll(roll);
  run.finalBossId = bossId;
  return {
    roll,
    bossId,
  };
}
