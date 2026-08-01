import { MAX_RELICS, type RunState } from '../core/RunState';
import type { RelicBand } from '../core/types';
import { ALL_RELICS, type RelicDef } from './RelicDatabase';

const RELIC_BAND_EXTRA: Record<RelicBand, number> = {
  SURVIVAL: 0x51555256,
  CORE: 0x434f5245,
  GREED_DAMAGE: 0x47524545,
};

export function relicBandFromVictoryRoll(roll: number): RelicBand {
  if (roll <= 8) return 'SURVIVAL';
  if (roll <= 14) return 'CORE';
  return 'GREED_DAMAGE';
}

export function offerRelics(run: RunState, band: RelicBand, count = 3): RelicDef[] {
  const requestedCount = normalizeCount(count);
  const openSlots = Math.max(0, MAX_RELICS - run.relics.length);
  const desiredCount = Math.min(requestedCount, openSlots);
  if (desiredCount <= 0) return [];

  const ownedIds = new Set(run.relics.map((relic) => relic.id));
  const pool = ALL_RELICS.filter((relic) => relic.band === band && !ownedIds.has(relic.id));
  const offers: RelicDef[] = [];
  const rng = run.rng('relic_choices', offerRngExtra(run, band, desiredCount));

  while (offers.length < desiredCount && pool.length > 0) {
    const index = pickWeightedIndex(rng, pool);
    const [picked] = pool.splice(index, 1);
    if (picked === undefined) break;
    offers.push(picked);
  }

  return offers;
}

export function offerRelicsForVictoryRoll(run: RunState, victoryRoll: number, count = 3): RelicDef[] {
  return offerRelics(run, relicBandFromVictoryRoll(victoryRoll), count);
}

function normalizeCount(count: number): number {
  if (!Number.isFinite(count)) return 0;
  return Math.max(0, Math.trunc(count));
}

function offerRngExtra(run: RunState, band: RelicBand, desiredCount: number): number {
  return (
    RELIC_BAND_EXTRA[band] ^
    Math.imul(run.relics.length + 1, 0x45d9f3b) ^
    Math.imul(desiredCount + 1, 0x119de1f3)
  ) >>> 0;
}

function pickWeightedIndex(rng: () => number, pool: readonly RelicDef[]): number {
  let totalWeight = 0;
  for (const relic of pool) {
    totalWeight += safeWeight(relic);
  }

  if (totalWeight <= 0) {
    return Math.floor(rng() * pool.length);
  }

  let cursor = rng() * totalWeight;
  for (let i = 0; i < pool.length; i++) {
    cursor -= safeWeight(pool[i]!);
    if (cursor < 0) return i;
  }

  return pool.length - 1;
}

function safeWeight(relic: RelicDef): number {
  if (!Number.isFinite(relic.weight)) return 0;
  return Math.max(0, relic.weight);
}
