import { bus, Events } from '../core/EventBus';
import type { RunState } from '../core/RunState';
import { MODIFIER_BY_ID, type ModifierDef, type ModifierEffectId } from './ModifierDatabase';

export interface CombatMods {
  enemyHpMult: number;
  enemyProjectileSpeedMult: number;
  enemyDamageMult: number;
  enemySpawnRateMult: number;
  eliteSpawnChanceAdd: number;
  hazardFrequencyMult: number;
  playerDamageMult: number;
  playerMoveSpeedMult: number;
  playerAttackSpeedMult: number;
  playerDamageTakenMult: number;
  playerGravityMult: number;
  playerCooldownRecoveryMult: number;
  playerDashRecoveryMult: number;
  playerKnockbackResistMult: number;
  playerHealOnFloor: number;
  aggroDelayMult: number;
  meterGainMult: number;
  goldFindMult: number;
  floorTimerMult: number;
}

export interface ModifierChosenPayload {
  modifier: ModifierDef;
  diceMin: number;
  diceMax: number;
  healAmount: number;
}

export function baseCombatMods(): CombatMods {
  return {
    enemyHpMult: 1,
    enemyProjectileSpeedMult: 1,
    enemyDamageMult: 1,
    enemySpawnRateMult: 1,
    eliteSpawnChanceAdd: 0,
    hazardFrequencyMult: 1,
    playerDamageMult: 1,
    playerMoveSpeedMult: 1,
    playerAttackSpeedMult: 1,
    playerDamageTakenMult: 1,
    playerGravityMult: 1,
    playerCooldownRecoveryMult: 1,
    playerDashRecoveryMult: 1,
    playerKnockbackResistMult: 1,
    playerHealOnFloor: 0,
    aggroDelayMult: 1,
    meterGainMult: 1,
    goldFindMult: 1,
    floorTimerMult: 1,
  };
}

export function canApplyModifier(run: RunState, modifier: ModifierDef): boolean {
  return modifier.exclusiveTag === undefined || !run.hasExclusive(modifier.exclusiveTag);
}

export function applyModifier(run: RunState, modifier: ModifierDef): boolean {
  if (!canApplyModifier(run, modifier)) return false;

  run.addModifier({
    id: modifier.id,
    name: modifier.name,
    delta: modifier.delta,
    exclusiveTag: modifier.exclusiveTag,
  });

  bus.emit<ModifierChosenPayload>(Events.MODIFIER_CHOSEN, {
    modifier,
    diceMin: run.dice.min,
    diceMax: run.dice.max,
    healAmount: modifier.effectId === 'heal' ? modifier.params.amount ?? 0 : 0,
  });

  return true;
}

export function removeModifierEffect(run: RunState, modifierId: string): boolean {
  const index = run.worldModifiers.findIndex((modifier) => modifier.id === modifierId);
  if (index < 0) return false;

  run.worldModifiers.splice(index, 1);
  return true;
}

export function removeModifiersByExclusiveTag(run: RunState, exclusiveTag: string): number {
  const before = run.worldModifiers.length;
  run.worldModifiers = run.worldModifiers.filter((modifier) => modifier.exclusiveTag !== exclusiveTag);
  return before - run.worldModifiers.length;
}

export function getModifierCombatMods(run: RunState): CombatMods {
  const mods = baseCombatMods();

  for (const active of run.worldModifiers) {
    const definition = MODIFIER_BY_ID.get(active.id);
    if (definition === undefined) continue;
    applyEffectToCombatMods(mods, definition.effectId, definition.params);
  }

  return mods;
}

function applyEffectToCombatMods(
  mods: CombatMods,
  effectId: ModifierEffectId,
  params: Record<string, number>,
): void {
  switch (effectId) {
    case 'heal':
      return;
    case 'enemy_hp_mult':
      mods.enemyHpMult *= readMult(params);
      return;
    case 'enemy_projectile_speed_mult':
      mods.enemyProjectileSpeedMult *= readMult(params);
      return;
    case 'enemy_damage_mult':
      mods.enemyDamageMult *= readMult(params);
      return;
    case 'player_damage_mult':
      mods.playerDamageMult *= readMult(params);
      return;
    case 'player_move_speed_mult':
      mods.playerMoveSpeedMult *= readMult(params);
      return;
    case 'player_attack_speed_mult':
      mods.playerAttackSpeedMult *= readMult(params);
      return;
    case 'gravity_mult':
      mods.playerGravityMult *= readMult(params);
      return;
    case 'damage_taken_mult':
      mods.playerDamageTakenMult *= readMult(params);
      return;
    case 'aggro_delay_mult':
      mods.aggroDelayMult *= readMult(params);
      return;
    case 'enemy_spawn_rate_mult':
      mods.enemySpawnRateMult *= readMult(params);
      return;
    case 'hazard_frequency_mult':
      mods.hazardFrequencyMult *= readMult(params);
      return;
    case 'player_heal_on_floor':
      mods.playerHealOnFloor += params.amount ?? 0;
      return;
    case 'elite_spawn_chance':
      mods.eliteSpawnChanceAdd += params.chance ?? 0;
      return;
    case 'cooldown_recovery_mult':
      mods.playerCooldownRecoveryMult *= readMult(params);
      return;
    case 'meter_gain_mult':
      mods.meterGainMult *= readMult(params);
      return;
    case 'gold_find_mult':
      mods.goldFindMult *= readMult(params);
      return;
    case 'dash_recovery_mult':
      mods.playerDashRecoveryMult *= readMult(params);
      return;
    case 'knockback_resist_mult':
      mods.playerKnockbackResistMult *= readMult(params);
      return;
    case 'floor_timer_mult':
      mods.floorTimerMult *= readMult(params);
      return;
  }
}

function readMult(params: Record<string, number>): number {
  return params.mult ?? 1;
}
