import type { ClassId } from '../core/types';

export interface PlayerCombatStats {
  lightDamage: number;
  heavyDamage: number;
  ultimateDamage: number;
  lightRecovery: number;
  heavyRecovery: number;
  critChance: number;
  critMult: number;
  ultimateCooldown: number;
  defendCooldown: number;
  rollTravelMult: number;
}

export interface ClassMovementStats {
  walkSpeed: number;
  sprintSpeed: number;
  dashSpeed: number;
  dashDuration: number;
}

export interface ClassAbilityLabels {
  light: string;
  heavy: string;
  defend: string;
  ultimate: string;
}

export interface ClassDef {
  id: ClassId;
  name: string;
  role: string;
  description: string;
  maxHealth: number;
  combat: Readonly<PlayerCombatStats>;
  movement: Readonly<ClassMovementStats>;
  kaykitAssetKey: ClassId;
  abilities: Readonly<ClassAbilityLabels>;
}

export const CLASS_DEFS: Readonly<Record<ClassId, ClassDef>> = {
  knight: {
    id: 'knight',
    name: 'Knight',
    role: 'Shielded Vanguard',
    description: 'Wide guard arcs, deliberate burst windows, and reliable Ascension Charge carries.',
    maxHealth: 100,
    combat: {
      lightDamage: 14,
      heavyDamage: 34,
      ultimateDamage: 70,
      lightRecovery: 0.26,
      heavyRecovery: 0.68,
      critChance: 0.1,
      critMult: 1.5,
      ultimateCooldown: 25,
      defendCooldown: 14,
      rollTravelMult: 1,
    },
    movement: {
      walkSpeed: 4.2,
      sprintSpeed: 6.15,
      dashSpeed: 13.5,
      dashDuration: 0.28,
    },
    kaykitAssetKey: 'knight',
    abilities: {
      light: 'Slash',
      heavy: 'Slam',
      defend: 'Guard',
      ultimate: 'Judgment',
    },
  },
  rogue: {
    id: 'rogue',
    name: 'Rogue',
    role: 'Tempo Duelist',
    description: 'Fast cancels, riskier spacing, and extra value from perfect dodge chimes.',
    maxHealth: 100,
    combat: {
      lightDamage: 11,
      heavyDamage: 26,
      ultimateDamage: 58,
      lightRecovery: 0.18,
      heavyRecovery: 0.48,
      critChance: 0.12,
      critMult: 1.5,
      ultimateCooldown: 25,
      defendCooldown: 14,
      rollTravelMult: 1.28,
    },
    movement: {
      walkSpeed: 4.45,
      sprintSpeed: 6.5,
      dashSpeed: 14.2,
      dashDuration: 0.28,
    },
    kaykitAssetKey: 'rogue',
    abilities: {
      light: 'Flurry',
      heavy: 'Lunge',
      defend: 'Evasion',
      ultimate: 'Tempest',
    },
  },
  mage: {
    id: 'mage',
    name: 'Mage',
    role: 'Arcane Controller',
    description: 'Ranged spells build Dice Meter while frost and void magic control the arena.',
    maxHealth: 100,
    combat: {
      lightDamage: 10,
      heavyDamage: 27,
      ultimateDamage: 72,
      lightRecovery: 0.22,
      heavyRecovery: 0.62,
      critChance: 0.1,
      critMult: 1.5,
      ultimateCooldown: 28,
      defendCooldown: 15,
      rollTravelMult: 0.92,
    },
    movement: {
      walkSpeed: 3.9,
      sprintSpeed: 5.7,
      dashSpeed: 12.5,
      dashDuration: 0.26,
    },
    kaykitAssetKey: 'mage',
    abilities: {
      light: 'Bolt',
      heavy: 'Nova',
      defend: 'Barrier',
      ultimate: 'Storm',
    },
  },
};

export function getClassDef(classId: ClassId): ClassDef {
  return CLASS_DEFS[classId];
}
