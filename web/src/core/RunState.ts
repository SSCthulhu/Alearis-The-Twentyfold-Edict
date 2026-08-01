import { DiceRange } from '../dice/DiceRange';
import { makeRng, rngInt, type RngContext } from './SeededRng';
import type { ClassId, FinalBossId, GamePhase, RelicBand, RelicRarity, RngDomain, WorldId } from './types';

export interface OwnedRelic {
  id: string;
  name: string;
  rarity: RelicRarity;
  band: RelicBand;
  effectId: string;
  params: Record<string, number>;
}

export const MAX_RELICS = 3;

export interface ActiveModifier {
  id: string;
  name: string;
  delta: number;
  exclusiveTag?: string;
}

const META_KEY = 'alearis_meta_v1';

export interface MetaProgression {
  /** Next-run start as N–N after a final clear. */
  startRange: number;
  clears: number;
  bestTimeSec: number;
}

export function loadMeta(): MetaProgression {
  try {
    const raw = localStorage.getItem(META_KEY);
    if (!raw) return { startRange: 10, clears: 0, bestTimeSec: 0 };
    const parsed = JSON.parse(raw) as MetaProgression;
    return {
      startRange: Math.max(1, Math.min(20, parsed.startRange ?? 10)),
      clears: parsed.clears ?? 0,
      bestTimeSec: parsed.bestTimeSec ?? 0,
    };
  } catch {
    return { startRange: 10, clears: 0, bestTimeSec: 0 };
  }
}

export function saveMeta(meta: MetaProgression): void {
  localStorage.setItem(META_KEY, JSON.stringify(meta));
}

/** Authoritative run state — dice, seed, world/floor, relics, meters. */
export class RunState {
  runSeed: number;
  classId: ClassId = 'knight';
  phase: GamePhase = 'boot';
  world: WorldId = 1;
  floor = 1;
  dice: DiceRange;
  lastRoll = 10;
  /** Snapshot of the victory/final-boss roll used for meta progression, immune to mid-fight meter invokes. */
  metaRoll: number | null = null;
  relics: OwnedRelic[] = [];
  worldModifiers: ActiveModifier[] = [];
  diceMeter = 0;
  /** Count of dice meter invokes this run; feeds RNG `extra` so consecutive invokes can differ. */
  meterInvokes = 0;
  enemiesRemaining = 0;
  floorElapsed = 0;
  runElapsed = 0;
  kills = 0;
  damageDealt = 0;
  damageMilestoneCursor = 0;
  finalBossId: FinalBossId | null = null;
  paused = false;
  tutorialDone = false;
  meta: MetaProgression;

  constructor(seed?: number, startRange?: number) {
    this.meta = loadMeta();
    this.runSeed = seed ?? (Math.floor(Math.random() * 0xffffffff) >>> 0);
    const n = startRange ?? this.meta.startRange;
    this.dice = new DiceRange(n, n);
    this.lastRoll = n;
  }

  rngContext(): RngContext {
    return {
      runSeed: this.runSeed,
      world: this.world,
      floor: this.floor,
      diceMin: this.dice.min,
      diceMax: this.dice.max,
      lastRoll: this.lastRoll,
    };
  }

  rng(domain: RngDomain, extra = 0): () => number {
    return makeRng(this.rngContext(), domain, extra);
  }

  /** Roll within current dice range; updates lastRoll. */
  roll(domain: RngDomain, extra = 0): number {
    const rng = this.rng(domain, extra);
    const value = rngInt(rng, this.dice.min, this.dice.max);
    this.lastRoll = value;
    return value;
  }

  hasExclusive(tag: string): boolean {
    return this.worldModifiers.some((m) => m.exclusiveTag === tag);
  }

  addModifier(mod: ActiveModifier): void {
    if (mod.exclusiveTag && this.hasExclusive(mod.exclusiveTag)) return;
    this.worldModifiers.push(mod);
    this.dice.applyDelta(mod.delta);
  }

  resetWorldModifiers(): void {
    this.worldModifiers = [];
  }

  addRelic(relic: OwnedRelic): boolean {
    if (this.relics.length >= MAX_RELICS) return false;
    if (this.relics.some((r) => r.id === relic.id)) return false;
    this.relics.push(relic);
    return true;
  }

  hasRelicEffect(effectId: string): boolean {
    return this.relics.some((r) => r.effectId === effectId);
  }

  relicParam(effectId: string, key: string, fallback = 0): number {
    const r = this.relics.find((x) => x.effectId === effectId);
    if (!r) return fallback;
    return r.params[key] ?? fallback;
  }

  chargeMeter(amount: number): void {
    this.diceMeter = Math.min(100, this.diceMeter + amount);
  }

  spendMeter(): boolean {
    if (this.diceMeter < 100) return false;
    this.diceMeter = 0;
    return true;
  }

  advanceFloor(): void {
    if (this.floor < 5) {
      this.floor += 1;
      return;
    }
    if (this.world < 3) {
      this.world = (this.world + 1) as WorldId;
      this.floor = 1;
      this.resetWorldModifiers();
      return;
    }
    this.world = 4;
    this.floor = 1;
  }

  isBossFloor(): boolean {
    return this.floor === 5 || this.world === 4;
  }

  recordClear(runTimeSec: number, finalRoll?: number): void {
    this.meta.clears += 1;
    const roll = finalRoll ?? this.metaRoll ?? this.lastRoll;
    this.meta.startRange = Math.max(1, Math.min(20, roll));
    if (this.meta.bestTimeSec <= 0 || runTimeSec < this.meta.bestTimeSec) {
      this.meta.bestTimeSec = runTimeSec;
    }
    saveMeta(this.meta);
  }
}
