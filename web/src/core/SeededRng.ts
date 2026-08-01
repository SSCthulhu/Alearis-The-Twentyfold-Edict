import type { RngDomain } from './types';

/** FNV-1a 32-bit hash — fast, deterministic string mixer. */
export function hashString(input: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/** Mulberry32 PRNG — compact, high-quality enough for gameplay streams. */
export function mulberry32(seed: number): () => number {
  let t = seed >>> 0;
  return () => {
    t = (t + 0x6d2b79f5) >>> 0;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

export interface RngContext {
  runSeed: number;
  world: number;
  floor: number;
  diceMin: number;
  diceMax: number;
  lastRoll: number;
}

/**
 * Domain-separated deterministic RNG.
 * mix: seed + world + floor + dice range + last roll + domain hash + extra
 */
export function makeRng(ctx: RngContext, domain: RngDomain, extra = 0): () => number {
  const domainHash = hashString(domain);
  const mixed =
    (ctx.runSeed >>> 0) ^
    Math.imul(ctx.world + 1, 0x9e3779b1) ^
    Math.imul(ctx.floor + 1, 0x85ebca6b) ^
    Math.imul(ctx.diceMin + 1, 0xc2b2ae35) ^
    Math.imul(ctx.diceMax + 1, 0x27d4eb2f) ^
    Math.imul(ctx.lastRoll + 1, 0x165667b1) ^
    domainHash ^
    (extra >>> 0);
  return mulberry32(mixed >>> 0);
}

export function rngInt(rng: () => number, min: number, max: number): number {
  if (max < min) return min;
  return min + Math.floor(rng() * (max - min + 1));
}

export function rngFloat(rng: () => number, min: number, max: number): number {
  return min + rng() * (max - min);
}

export function rngPick<T>(rng: () => number, arr: readonly T[]): T {
  return arr[Math.floor(rng() * arr.length)]!;
}

export function rngShuffle<T>(rng: () => number, arr: T[]): T[] {
  const out = arr.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    const tmp = out[i]!;
    out[i] = out[j]!;
    out[j] = tmp;
  }
  return out;
}
