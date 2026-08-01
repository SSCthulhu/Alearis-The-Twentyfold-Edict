import * as THREE from 'three';
import type { ActiveCouncilEvent } from './DiceMeter';
import { baseCombatMods, type CombatMods } from './ModifierEffects';

export interface CouncilEffectsContext {
  readonly playerPosition: THREE.Vector3;
  /** World-modifier hazard cadence multiplier (thorn_candles etc.). */
  readonly hazardFrequencyMult: number;
  readonly healPlayer: (amount: number) => number;
  readonly applyTemporaryShield: (duration: number, damageReduction: number) => void;
  readonly applyNonlethalHazardDamage: (amount: number) => number;
  readonly spawnHazardPulse: (position: THREE.Vector3, radius: number, color?: string) => void;
  /** Slows (chills) enemies within radius of the player for the given duration. */
  readonly applyEnemySlow: (radius: number, duration: number) => void;
  /** Spawns fragile mirror shades through the active encounter. */
  readonly spawnMirrorShades: (count: number, hpMult: number) => void;
  readonly rng: () => number;
}

interface CouncilTickState {
  eventId: string;
  elapsed: number;
  pulseTimer: number;
  onceApplied: boolean;
}

let tickState: CouncilTickState | null = null;

export function getCouncilCombatMods(active: ActiveCouncilEvent | null): CombatMods {
  const mods = baseCombatMods();
  if (active === null) return mods;

  const params = active.event.params;
  switch (active.event.effectId) {
    case 'edict_projectile_bloom':
      mods.enemyProjectileSpeedMult *= params.speedMult ?? 1;
      return mods;
    case 'council_gravity_trial':
      mods.playerGravityMult *= params.gravityMult ?? 1;
      return mods;
    case 'divine_forge_overheat':
      mods.enemyDamageTakenMult *= params.enemyDamageTakenMult ?? 1;
      return mods;
    case 'council_silence':
      mods.playerCooldownRecoveryMult *= params.cooldownRecoveryMult ?? 1;
      return mods;
    case 'divine_bulwark':
      mods.playerDamageTakenMult *= params.damageTakenMult ?? 1;
      mods.playerKnockbackResistMult *= params.knockbackResistMult ?? 1;
      return mods;
    case 'divine_fate_echo':
      mods.playerMoveSpeedMult *= params.echoSpeedMult ?? 1.18;
      mods.playerAttackSpeedMult *= params.echoSpeedMult ?? 1.18;
      return mods;
    case 'council_enemy_ward':
      // Ward blocks a portion of every player hit while it rotates.
      mods.enemyDamageTakenMult *= 1 - THREE.MathUtils.clamp(params.damageBlockedMult ?? 0.35, 0, 0.8);
      return mods;
    case 'divine_smite_glyphs':
      mods.enemyDamageTakenMult *= params.bonusDamageMult ?? 1.25;
      return mods;
    case 'divine_clarity':
      mods.enemyProjectileSpeedMult *= params.projectileSpeedMult ?? 0.82;
      mods.enemyWindupAddSeconds += params.telegraphSecondsAdd ?? 0.35;
      return mods;
    case 'divine_ascendant_haste':
      mods.playerMoveSpeedMult *= params.moveSpeedMult ?? 1;
      mods.playerCooldownRecoveryMult *= params.cooldownRecoveryMult ?? 1;
      return mods;
    case 'dice_god_intervention':
      mods.playerMoveSpeedMult *= params.moveSpeedMult ?? 1;
      mods.enemyProjectileSpeedMult *= params.enemyProjectileSpeedMult ?? 1;
      return mods;
    default:
      return mods;
  }
}

export function tickCouncilEffects(
  dt: number,
  active: ActiveCouncilEvent,
  ctx: CouncilEffectsContext,
): void {
  if (tickState === null || tickState.eventId !== active.event.id) {
    tickState = {
      eventId: active.event.id,
      elapsed: 0,
      pulseTimer: 0,
      onceApplied: false,
    };
  }

  tickState.elapsed += Math.max(0, dt);
  applyOnceEffects(active, ctx);
  tickPeriodicEffects(dt, active, ctx);
}

function applyOnceEffects(active: ActiveCouncilEvent, ctx: CouncilEffectsContext): void {
  if (tickState === null || tickState.onceApplied) return;

  const params = active.event.params;
  if (active.event.effectId === 'divine_mending_rain') {
    const heal = (params.healPerPool ?? 6) * Math.max(1, Math.trunc(params.poolCount ?? 1));
    if (ctx.healPlayer(heal) > 0) ctx.spawnHazardPulse(ctx.playerPosition.clone().add(new THREE.Vector3(0, 0.9, 0)), params.poolRadius ?? 2.4);
  } else if (active.event.effectId === 'dice_god_intervention') {
    if (ctx.healPlayer(params.heal ?? 20) > 0) ctx.spawnHazardPulse(ctx.playerPosition.clone().add(new THREE.Vector3(0, 0.9, 0)), 2.2);
  } else if (active.event.effectId === 'divine_kallos_barrier') {
    ctx.applyTemporaryShield(params.barrierSeconds ?? active.remaining, 0.35);
    ctx.spawnHazardPulse(ctx.playerPosition.clone().add(new THREE.Vector3(0, 0.8, 0)), 2);
  } else if (active.event.effectId === 'council_mirror_spawns') {
    ctx.spawnMirrorShades(Math.max(1, Math.trunc(params.shadeCount ?? 2)), params.shadeHpMult ?? 0.35);
    ctx.spawnHazardPulse(ctx.playerPosition.clone().add(new THREE.Vector3(0, 0.9, 0)), 1.6, '#b48cff');
  }

  tickState.onceApplied = true;
}

function tickPeriodicEffects(dt: number, active: ActiveCouncilEvent, ctx: CouncilEffectsContext): void {
  if (tickState === null) return;
  const effectId = active.event.effectId;

  if (isHazardEvent(effectId)) {
    tickHazards(dt, active, ctx);
    return;
  }
  if (effectId === 'divine_frost_stasis') {
    tickFrostStasis(dt, active, ctx);
    return;
  }
  if (effectId === 'council_void_lanterns') {
    tickVoidLanterns(dt, active, ctx);
  }
}

function tickHazards(dt: number, active: ActiveCouncilEvent, ctx: CouncilEffectsContext): void {
  if (tickState === null) return;

  const params = active.event.params;
  const frequencyMult = (params.hazardFrequencyMult ?? 1) * Math.max(0.1, ctx.hazardFrequencyMult);
  const pulseCount = Math.max(1, params.hazardPulses ?? params.sigilCount ?? 4);
  const interval = Math.max(0.7, active.event.duration / pulseCount / frequencyMult);
  if (!advancePulseTimer(dt, interval)) return;

  const offset = new THREE.Vector3((ctx.rng() - 0.5) * 2.4, 0.2 + ctx.rng() * 0.7, 0);
  const position = ctx.playerPosition.clone().add(offset);
  const radius = active.event.effectId === 'council_final_exam' ? 1.25 : 1;
  ctx.spawnHazardPulse(position, radius);
  ctx.applyNonlethalHazardDamage(6 + ctx.rng() * 2);
}

function tickFrostStasis(dt: number, active: ActiveCouncilEvent, ctx: CouncilEffectsContext): void {
  const params = active.event.params;
  const pulseCount = Math.max(1, params.pulseCount ?? 3);
  const interval = Math.max(0.7, active.event.duration / pulseCount);
  if (!advancePulseTimer(dt, interval)) return;

  const radius = params.radius ?? 3;
  ctx.applyEnemySlow(radius, interval * 1.25);
  ctx.spawnHazardPulse(ctx.playerPosition.clone().add(new THREE.Vector3(0, 0.9, 0)), radius * 0.6, '#9adcff');
}

function tickVoidLanterns(dt: number, active: ActiveCouncilEvent, ctx: CouncilEffectsContext): void {
  const params = active.event.params;
  const pulseCount = Math.max(1, params.lanternCount ?? 5);
  const frequencyMult = Math.max(0.1, ctx.hazardFrequencyMult);
  const interval = Math.max(0.9, active.event.duration / pulseCount / frequencyMult);
  if (!advancePulseTimer(dt, interval)) return;

  const offset = new THREE.Vector3((ctx.rng() - 0.5) * 3.2, 0.3 + ctx.rng() * 0.9, 0);
  ctx.spawnHazardPulse(ctx.playerPosition.clone().add(offset), 0.9, '#8a5aff');
  ctx.applyNonlethalHazardDamage(2 + ctx.rng() * 2);
}

/** Shared pulse cadence: returns true when a pulse fires this frame. */
function advancePulseTimer(dt: number, interval: number): boolean {
  if (tickState === null) return false;
  tickState.pulseTimer -= Math.max(0, dt);
  if (tickState.pulseTimer > 0) return false;
  tickState.pulseTimer = interval;
  return true;
}

function isHazardEvent(effectId: ActiveCouncilEvent['event']['effectId']): boolean {
  return (
    effectId === 'catastrophe_pressure' ||
    effectId === 'council_blood_tithe' ||
    effectId === 'council_chain_floor' ||
    effectId === 'council_final_exam'
  );
}
