import * as THREE from 'three';
import type { ClassId, AABB } from '../core/types';
import type { FigureAnimState } from '../actors/ProceduralFigure';
import type { PlayerBuffs } from './PlayerBuffs';
import { getClassDef, type PlayerCombatStats } from './ClassDefs';

export type { PlayerCombatStats } from './ClassDefs';

export type PlayerCombatEventKind =
  | 'light'
  | 'arcane_bolt'
  | 'heavy'
  | 'frost_nova'
  | 'dash_attack'
  | 'defend'
  | 'ultimate_wave'
  | 'ultimate_burst'
  | 'ultimate_storm';

export interface PlayerCombatEvent {
  kind: PlayerCombatEventKind;
  classId: ClassId;
  origin: THREE.Vector3;
  facing: number;
  hitbox: AABB;
  damage: number;
  crit: boolean;
  knockback: number;
  duration: number;
  elemental: 'frost' | 'void' | 'forge' | 'fate' | 'none';
}

interface ActiveAttack {
  state: FigureAnimState;
  remaining: number;
  total: number;
}

export function getPlayerCombatStats(classId: ClassId): PlayerCombatStats {
  return { ...getClassDef(classId).combat };
}

export class PlayerCombat {
  readonly classId: ClassId;
  readonly stats: PlayerCombatStats;
  private readonly buffs: PlayerBuffs;
  private rng: () => number;
  private activeAttack: ActiveAttack | null = null;
  private lightComboIndex = 0;
  private comboGrace = 0;
  private ultimateRemaining = 0;
  private defendRemaining = 0;
  private critChanceBonus = 0;
  damageMult = 1;
  cooldownRecoveryMult = 1;
  /** Modifier/council attack speed (player_attack_speed_mult, divine_fate_echo); scales attack recovery. */
  attackSpeedMult = 1;

  constructor(classId: ClassId, buffs: PlayerBuffs, rng: () => number = Math.random) {
    this.classId = classId;
    this.stats = getPlayerCombatStats(classId);
    this.buffs = buffs;
    this.rng = rng;
  }

  get busy(): boolean {
    return this.activeAttack !== null;
  }

  get ultimateCooldownRemaining(): number {
    return this.ultimateRemaining;
  }

  get defendCooldownRemaining(): number {
    return this.defendRemaining;
  }

  setRng(rng: () => number): void {
    this.rng = rng;
  }

  setCritChanceBonus(bonus: number): void {
    this.critChanceBonus = THREE.MathUtils.clamp(bonus, 0, 0.85);
  }

  update(dt: number): void {
    const cooldownDt = dt * this.cooldownRecoveryMult;
    this.ultimateRemaining = Math.max(0, this.ultimateRemaining - cooldownDt);
    this.defendRemaining = Math.max(0, this.defendRemaining - cooldownDt);
    this.comboGrace = Math.max(0, this.comboGrace - dt);
    if (this.comboGrace <= 0) this.lightComboIndex = 0;

    if (!this.activeAttack) return;
    this.activeAttack.remaining -= dt * this.buffs.attackSpeedMultiplier() * this.attackSpeedMult;
    if (this.activeAttack.remaining <= 0) this.activeAttack = null;
  }

  requestLight(position: THREE.Vector3, facing: number): PlayerCombatEvent | null {
    if (this.busy) return null;
    if (this.classId === 'mage') {
      const event = this.createAttackEvent(
        'arcane_bolt',
        position,
        facing,
        this.stats.lightDamage,
        1.7,
        0.72,
        0.35,
        0.12,
        'void',
      );
      this.lightComboIndex = 0;
      this.comboGrace = 0;
      this.setActiveAttack('cast', this.stats.lightRecovery);
      return event;
    }

    const comboBonus = this.classId === 'rogue' ? this.lightComboIndex * 0.16 : this.lightComboIndex * 0.08;
    const range = this.classId === 'rogue' ? 1.05 + this.lightComboIndex * 0.08 : 1.18;
    const height = 1.0;
    const event = this.createAttackEvent(
      'light',
      position,
      facing,
      this.stats.lightDamage * (1 + comboBonus),
      range,
      height,
      0.72,
      0.12,
    );
    this.lightComboIndex = (this.lightComboIndex + 1) % (this.classId === 'rogue' ? 4 : 3);
    this.comboGrace = 0.64;
    this.setActiveAttack('attack', this.stats.lightRecovery);
    return event;
  }

  requestHeavy(position: THREE.Vector3, facing: number): PlayerCombatEvent | null {
    if (this.busy) return null;
    if (this.classId === 'mage') {
      const event = this.createCenteredAttackEvent(
        'frost_nova',
        position,
        facing,
        this.stats.heavyDamage,
        2.35,
        1.65,
        1.15,
        0.38,
        'frost',
      );
      this.setActiveAttack('cast', this.stats.heavyRecovery);
      return event;
    }
    if (this.classId === 'rogue') {
      const event = this.createAttackEvent('dash_attack', position, facing, this.stats.heavyDamage, 1.55, 0.78, 1.25, 0.18);
      this.setActiveAttack('attack', this.stats.heavyRecovery);
      return event;
    }

    const range = 1.85;
    const height = 1.35;
    const event = this.createAttackEvent('heavy', position, facing, this.stats.heavyDamage, range, height, 1.45, 0.24);
    this.setActiveAttack('attack', this.stats.heavyRecovery);
    return event;
  }

  requestDefend(position: THREE.Vector3, facing: number): PlayerCombatEvent | null {
    if (this.defendRemaining > 0) return null;
    this.defendRemaining = this.stats.defendCooldown;
    if (this.classId === 'knight') {
      this.buffs.apply({
        id: 'knight_shield',
        duration: 10,
        damageReduction: 0.2,
        moveSpeedMult: 0.94,
        source: 'knight_defend',
      });
    } else if (this.classId === 'rogue') {
      this.buffs.apply({
        id: 'rogue_evasion',
        duration: 8,
        dodgeChance: 0.45,
        moveSpeedMult: 1.06,
        source: 'rogue_defend',
      });
    } else {
      this.buffs.apply({
        id: 'mage_arcane_barrier',
        duration: 7,
        damageReduction: 0.28,
        moveSpeedMult: 0.92,
        source: 'mage_defend',
      });
    }
    return this.createUtilityEvent('defend', position, facing, 0, 0.9, 1.2, 0);
  }

  requestUltimate(position: THREE.Vector3, facing: number): PlayerCombatEvent | null {
    if (this.busy || this.ultimateRemaining > 0) return null;
    this.ultimateRemaining = this.stats.ultimateCooldown;
    if (this.classId === 'mage') {
      const event = this.createCenteredAttackEvent(
        'ultimate_storm',
        position,
        facing,
        this.stats.ultimateDamage,
        3.4,
        5.3,
        2.4,
        0.72,
        'void',
      );
      this.buffs.apply({ id: 'ultimate_empower', duration: 1.25, attackSpeedMult: 1.08, source: 'ultimate' });
      this.setActiveAttack('cast', 0.88);
      return event;
    }

    const kind: PlayerCombatEventKind = this.classId === 'knight' ? 'ultimate_wave' : 'ultimate_burst';
    const range = this.classId === 'knight' ? 6.25 : 4.4;
    const height = 1.6;
    const event = this.createAttackEvent(kind, position, facing, this.stats.ultimateDamage, range, height, 2.2, 0.46);
    this.buffs.apply({ id: 'ultimate_empower', duration: 1.25, attackSpeedMult: 1.08, source: 'ultimate' });
    this.setActiveAttack('attack', 0.78);
    return event;
  }

  cancelForDodge(): void {
    if (!this.activeAttack) return;
    this.activeAttack = null;
  }

  animationState(): FigureAnimState {
    if (!this.activeAttack) return { name: 'idle' };
    const attackT = 1 - this.activeAttack.remaining / Math.max(0.001, this.activeAttack.total);
    return { ...this.activeAttack.state, attackT };
  }

  private createAttackEvent(
    kind: PlayerCombatEventKind,
    position: THREE.Vector3,
    facing: number,
    baseDamage: number,
    range: number,
    height: number,
    knockback: number,
    duration: number,
    elemental: PlayerCombatEvent['elemental'] = 'none',
  ): PlayerCombatEvent {
    const crit = this.rng() < THREE.MathUtils.clamp(this.stats.critChance + this.critChanceBonus, 0, 0.85);
    const damage = baseDamage * this.damageMult * (crit ? this.stats.critMult : 1);
    return this.createUtilityEvent(kind, position, facing, damage, range, height, knockback, duration, crit, elemental);
  }

  private createCenteredAttackEvent(
    kind: PlayerCombatEventKind,
    position: THREE.Vector3,
    facing: number,
    baseDamage: number,
    radius: number,
    height: number,
    knockback: number,
    duration: number,
    elemental: PlayerCombatEvent['elemental'],
  ): PlayerCombatEvent {
    const event = this.createAttackEvent(
      kind,
      position,
      facing,
      baseDamage,
      radius * 2,
      height,
      knockback,
      duration,
      elemental,
    );
    event.hitbox.x = position.x - radius;
    event.hitbox.y = position.y - 0.1;
    return event;
  }

  private createUtilityEvent(
    kind: PlayerCombatEventKind,
    position: THREE.Vector3,
    facing: number,
    damage: number,
    range: number,
    height: number,
    knockback: number,
    duration = 0.1,
    crit = false,
    elemental: PlayerCombatEvent['elemental'] = 'none',
  ): PlayerCombatEvent {
    const front = facing >= 0 ? position.x + 0.28 : position.x - 0.28 - range;
    return {
      kind,
      classId: this.classId,
      origin: position.clone(),
      facing: facing >= 0 ? 1 : -1,
      hitbox: {
        x: front,
        y: position.y + 0.25,
        w: range,
        h: height,
      },
      damage,
      crit,
      knockback,
      duration,
      elemental,
    };
  }

  private setActiveAttack(name: FigureAnimState['name'], duration: number): void {
    const total = Math.max(0.05, duration / (this.buffs.attackSpeedMultiplier() * Math.max(0.1, this.attackSpeedMult)));
    this.activeAttack = {
      state: { name, attackT: 0, intensity: this.classId === 'knight' ? 1.15 : 1 },
      remaining: total,
      total,
    };
  }
}
