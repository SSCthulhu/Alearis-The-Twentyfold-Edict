import type * as THREE from 'three';
import type { EnemyFigureKind, FigureColors } from '../actors/ProceduralFigure';
import type { ProjectilePattern, ProjectilePayload } from '../combat/Projectiles';
import type { StatusEffectId } from '../combat/StatusEffects';

export type EnemyKind = EnemyFigureKind;

export type EnemyAiState =
  | 'idle'
  | 'patrol'
  | 'aggroDelay'
  | 'chase'
  | 'windup'
  | 'recovery'
  | 'stunned'
  | 'dead';

export type EnemyDamageType = 'melee' | 'ranged' | 'projectile' | 'status' | 'environment';

export interface PlatformSpan {
  id?: string;
  xMin: number;
  xMax: number;
  y: number;
}

export interface EnemyAttackConfig {
  pattern: ProjectilePattern;
  payload: ProjectilePayload;
  count: number;
  speed: number;
  lifetime: number;
  spread?: number;
  radius?: number;
  scale?: number;
  color?: THREE.ColorRepresentation;
  status?: StatusEffectId;
}

export interface EnemyConfig {
  kind: EnemyKind;
  displayName: string;
  maxHp: number;
  patrolSpeed: number;
  chaseSpeed: number;
  aggroRange: number;
  deaggroRange: number;
  aggroDelay: number;
  attackRange: number;
  stopRange: number;
  contactDamage: number;
  contactRadius: number;
  contactCooldown: number;
  meleeDamage: number;
  meleeRange: number;
  meleeArc: number;
  windup: number;
  recovery: number;
  attackCooldown: number;
  edgeMargin: number;
  elite: boolean;
  projectile?: EnemyAttackConfig;
  summonKind?: EnemyKind;
  summonCount?: number;
  rangedImmuneUnlessClose?: boolean;
  rangedCloseRange?: number;
}

export interface EnemyDamagePacket {
  amount: number;
  source: 'player' | 'enemy' | 'boss' | 'hazard' | 'system';
  type: EnemyDamageType;
  crit?: boolean;
  status?: StatusEffectId;
  statusDuration?: number;
  sourcePosition?: THREE.Vector3;
  knockback?: number;
}

export interface EnemyDamageResult {
  applied: number;
  killed: boolean;
  ignored: boolean;
  reason?: string;
}

export const ENEMY_CONFIGS: Record<EnemyKind, EnemyConfig> = {
  meleeKnightAdd: {
    kind: 'meleeKnightAdd',
    displayName: 'Edict Knight Add',
    maxHp: 72,
    patrolSpeed: 1.45,
    chaseSpeed: 2.35,
    aggroRange: 7.5,
    deaggroRange: 11,
    aggroDelay: 0.42,
    attackRange: 1.25,
    stopRange: 0.9,
    contactDamage: 8,
    contactRadius: 0.55,
    contactCooldown: 0.75,
    meleeDamage: 16,
    meleeRange: 1.35,
    meleeArc: Math.PI * 0.55,
    windup: 0.36,
    recovery: 0.48,
    attackCooldown: 0.55,
    edgeMargin: 0.65,
    elite: false,
  },
  necromancer: {
    kind: 'necromancer',
    displayName: 'Blood Necromancer',
    maxHp: 86,
    patrolSpeed: 0.85,
    chaseSpeed: 1.25,
    aggroRange: 9.25,
    deaggroRange: 13,
    aggroDelay: 0.45,
    attackRange: 6.8,
    stopRange: 5.2,
    contactDamage: 6,
    contactRadius: 0.5,
    contactCooldown: 1,
    meleeDamage: 8,
    meleeRange: 0.9,
    meleeArc: Math.PI * 0.35,
    windup: 0.72,
    recovery: 0.72,
    attackCooldown: 1.2,
    edgeMargin: 0.8,
    elite: false,
    projectile: {
      pattern: 'cone',
      payload: { damage: 14, owner: 'enemy', status: 'bleed', knockback: 0.8 },
      count: 3,
      speed: 5.8,
      lifetime: 2.3,
      spread: Math.PI * 0.18,
      radius: 0.2,
      scale: 0.95,
      color: '#b52238',
      status: 'bleed',
    },
    summonKind: 'minionSkeleton',
    summonCount: 2,
  },
  skeletonMage: {
    kind: 'skeletonMage',
    displayName: 'Skeleton Mage',
    maxHp: 46,
    patrolSpeed: 0.95,
    chaseSpeed: 1.5,
    aggroRange: 8.2,
    deaggroRange: 12,
    aggroDelay: 0.4,
    attackRange: 6,
    stopRange: 4.5,
    contactDamage: 5,
    contactRadius: 0.45,
    contactCooldown: 1,
    meleeDamage: 6,
    meleeRange: 0.8,
    meleeArc: Math.PI * 0.35,
    windup: 0.58,
    recovery: 0.56,
    attackCooldown: 0.85,
    edgeMargin: 0.7,
    elite: false,
    projectile: {
      pattern: 'line',
      payload: { damage: 13, owner: 'enemy', status: 'shocked', knockback: 0.5 },
      count: 1,
      speed: 7.1,
      lifetime: 2,
      radius: 0.22,
      scale: 0.9,
      color: '#ff7a32',
      status: 'shocked',
    },
  },
  rogueSkeleton: {
    kind: 'rogueSkeleton',
    displayName: 'Rogue Skeleton Sniper',
    maxHp: 38,
    patrolSpeed: 1.25,
    chaseSpeed: 1.9,
    aggroRange: 10.5,
    deaggroRange: 14,
    aggroDelay: 0.48,
    attackRange: 8.4,
    stopRange: 6.6,
    contactDamage: 7,
    contactRadius: 0.46,
    contactCooldown: 0.9,
    meleeDamage: 9,
    meleeRange: 0.85,
    meleeArc: Math.PI * 0.35,
    windup: 0.82,
    recovery: 0.68,
    attackCooldown: 1.05,
    edgeMargin: 0.9,
    elite: false,
    projectile: {
      pattern: 'line',
      payload: { damage: 22, owner: 'enemy', knockback: 1.4 },
      count: 1,
      speed: 10.5,
      lifetime: 1.4,
      radius: 0.16,
      scale: 0.7,
      color: '#d7f2ff',
    },
  },
  skeletonGolem: {
    kind: 'skeletonGolem',
    displayName: 'Skeleton Golem',
    maxHp: 185,
    patrolSpeed: 0.62,
    chaseSpeed: 1.05,
    aggroRange: 8.5,
    deaggroRange: 12,
    aggroDelay: 0.5,
    attackRange: 1.65,
    stopRange: 1.15,
    contactDamage: 16,
    contactRadius: 0.82,
    contactCooldown: 0.9,
    meleeDamage: 30,
    meleeRange: 1.85,
    meleeArc: Math.PI * 0.68,
    windup: 0.82,
    recovery: 0.9,
    attackCooldown: 0.75,
    edgeMargin: 1.05,
    elite: true,
    projectile: {
      pattern: 'arc',
      payload: { damage: 12, owner: 'enemy', knockback: 1.1 },
      count: 5,
      speed: 4.9,
      lifetime: 2.4,
      spread: Math.PI * 0.65,
      radius: 0.24,
      scale: 1.05,
      color: '#d6c7aa',
    },
    rangedImmuneUnlessClose: true,
    rangedCloseRange: 2.4,
  },
  minionSkeleton: {
    kind: 'minionSkeleton',
    displayName: 'Minion Skeleton',
    maxHp: 24,
    patrolSpeed: 1.35,
    chaseSpeed: 2.15,
    aggroRange: 6.2,
    deaggroRange: 9.5,
    aggroDelay: 0.38,
    attackRange: 0.95,
    stopRange: 0.6,
    contactDamage: 5,
    contactRadius: 0.42,
    contactCooldown: 0.65,
    meleeDamage: 9,
    meleeRange: 1.0,
    meleeArc: Math.PI * 0.42,
    windup: 0.28,
    recovery: 0.34,
    attackCooldown: 0.4,
    edgeMargin: 0.55,
    elite: false,
  },
};

export const DEFAULT_ENEMY_COLORS: Record<EnemyKind, FigureColors> = {
  meleeKnightAdd: {
    skin: '#b98562',
    cloth: '#2e263d',
    armor: '#9aa1aa',
    accent: '#d7b151',
    weapon: '#c8d0d8',
    ink: '#17131c',
  },
  necromancer: {
    skin: '#a87883',
    cloth: '#241128',
    armor: '#4b314d',
    accent: '#d33353',
    weapon: '#d2c3a4',
    magic: '#ff3d66',
    ink: '#100713',
  },
  skeletonMage: {
    cloth: '#20344e',
    bone: '#d6ccb4',
    accent: '#ff7a32',
    weapon: '#d9c8aa',
    magic: '#ff9b3d',
    ink: '#15141a',
  },
  rogueSkeleton: {
    cloth: '#1b2433',
    bone: '#d8d0be',
    accent: '#80d8ff',
    weapon: '#dbeaf0',
    magic: '#c8f4ff',
    ink: '#111820',
  },
  skeletonGolem: {
    cloth: '#3a3328',
    bone: '#d6c7aa',
    armor: '#8b8170',
    accent: '#ffcf5c',
    weapon: '#8a7d68',
    ink: '#15100b',
  },
  minionSkeleton: {
    cloth: '#2f2a32',
    bone: '#d7ceb8',
    accent: '#bbd2e0',
    weapon: '#d0c8b4',
    ink: '#15141a',
  },
};

export function getEnemyConfig(kind: EnemyKind): EnemyConfig {
  return ENEMY_CONFIGS[kind];
}
