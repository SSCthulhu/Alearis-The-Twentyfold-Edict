import * as THREE from 'three';
import type { ActiveCouncilEvent } from './DiceMeter';
import { baseCombatMods, type CombatMods } from './ModifierEffects';

export interface CouncilEffectsContext {
  readonly playerPosition: THREE.Vector3;
  readonly healPlayer: (amount: number) => number;
  readonly applyTemporaryShield: (duration: number, damageReduction: number) => void;
  readonly applyNonlethalHazardDamage: (amount: number) => number;
  readonly spawnHazardPulse: (position: THREE.Vector3, radius: number) => void;
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
  tickHazards(dt, active, ctx);
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
  }

  tickState.onceApplied = true;
}

function tickHazards(dt: number, active: ActiveCouncilEvent, ctx: CouncilEffectsContext): void {
  if (tickState === null || !isHazardEvent(active.event.effectId)) return;

  const params = active.event.params;
  const frequencyMult = params.hazardFrequencyMult ?? 1;
  const pulseCount = Math.max(1, params.hazardPulses ?? params.sigilCount ?? 4);
  const interval = Math.max(0.7, active.event.duration / pulseCount / frequencyMult);
  tickState.pulseTimer -= Math.max(0, dt);
  if (tickState.pulseTimer > 0) return;

  tickState.pulseTimer = interval;
  const offset = new THREE.Vector3((ctx.rng() - 0.5) * 2.4, 0.2 + ctx.rng() * 0.7, 0);
  const position = ctx.playerPosition.clone().add(offset);
  const radius = active.event.effectId === 'council_final_exam' ? 1.25 : 1;
  ctx.spawnHazardPulse(position, radius);
  ctx.applyNonlethalHazardDamage(6 + ctx.rng() * 2);
}

function isHazardEvent(effectId: ActiveCouncilEvent['event']['effectId']): boolean {
  return (
    effectId === 'catastrophe_pressure' ||
    effectId === 'council_blood_tithe' ||
    effectId === 'council_chain_floor' ||
    effectId === 'council_final_exam'
  );
}
