import * as THREE from 'three';
import { bus, Events } from '../core/EventBus';
import type { RunState } from '../core/RunState';
import type { WorldId } from '../core/types';
import { getModifierCombatMods, type CombatMods } from '../dice/ModifierEffects';
import { EnemyBase, type EnemyAiContext, type EnemyFrameEvents } from '../enemies/EnemyBase';
import { MeleeKnightAdd } from '../enemies/MeleeKnightAdd';
import { MinionSkeleton } from '../enemies/MinionSkeleton';
import { Necromancer } from '../enemies/Necromancer';
import { RogueSkeleton } from '../enemies/RogueSkeleton';
import { SkeletonGolem } from '../enemies/SkeletonGolem';
import { SkeletonMage } from '../enemies/SkeletonMage';
import type { EnemyKind, PlatformSpan } from '../enemies/EnemyTypes';
import type { Arena } from './ArenaBuilder';
import type { FloorClearedPayload } from './FloorProgression';

interface WeightedEnemy {
  kind: EnemyKind;
  weight: number;
}

export interface EncounterDifficulty {
  hpMult: number;
  damageMult: number;
  projectileSpeedMult: number;
  spawnCount: number;
  eliteSpawnChance: number;
}

export interface EncounterFrame extends EnemyFrameEvents {
  aliveCount: number;
  spawned: EnemyBase[];
}

export class EncounterController {
  readonly root = new THREE.Group();
  readonly run: RunState;
  readonly arena: Arena;
  readonly enemies: EnemyBase[] = [];
  readonly platformSpans: PlatformSpan[];
  private readonly rng: () => number;
  private readonly combatMods: CombatMods;
  private readonly difficulty: EncounterDifficulty;
  private clearedEmitted = false;

  constructor(run: RunState, arena: Arena) {
    this.run = run;
    this.arena = arena;
    this.rng = run.rng('encounter', arena.world * 100 + arena.floor);
    this.combatMods = getModifierCombatMods(run);
    this.difficulty = this.createDifficulty();
    this.platformSpans = arena.platforms.map((platform) => ({
      id: platform.id,
      xMin: platform.aabb.x,
      xMax: platform.aabb.x + platform.aabb.w,
      y: platform.topY,
    }));
    this.root.name = `encounter_world_${arena.world}_floor_${arena.floor}`;
  }

  get aliveCount(): number {
    return this.enemies.reduce((count, enemy) => count + (enemy.alive ? 1 : 0), 0);
  }

  spawnInitialWave(): EnemyBase[] {
    this.clear();
    const spawned: EnemyBase[] = [];
    const anchors = this.arena.enemyAnchors.length > 0 ? this.arena.enemyAnchors : this.arena.spawns.enemies;
    const spawnCount = Math.min(this.difficulty.spawnCount, Math.max(1, anchors.length));

    for (let i = 0; i < spawnCount; i++) {
      const anchor = anchors[i % anchors.length]!;
      const kind = this.pickEnemyKind(this.arena.world, this.arena.floor);
      const jitter = (this.rng() - 0.5) * 0.42;
      spawned.push(this.spawnEnemy(kind, new THREE.Vector3(anchor.x + jitter, anchor.y, 0)));
    }

    this.run.enemiesRemaining = this.aliveCount;
    this.checkForClear();
    return spawned;
  }

  update(
    dt: number,
    playerPosition: THREE.Vector3,
    lineOfSight?: (from: THREE.Vector3, to: THREE.Vector3) => boolean,
  ): EncounterFrame {
    const frame = this.createFrame();
    const ctx: EnemyAiContext = {
      playerPosition,
      platforms: this.platformSpans,
      rng: this.rng,
      playerHurtboxRadius: 0.38,
      lineOfSight,
    };

    for (const enemy of this.enemies) {
      const enemyFrame = enemy.update(dt, ctx);
      this.applyDifficultyToEvents(enemyFrame);
      this.mergeFrame(frame, enemyFrame);
      for (const summon of enemyFrame.summons) {
        const spawned = this.spawnEnemy(summon.kind, summon.position);
        frame.spawned.push(spawned);
      }
    }

    this.run.enemiesRemaining = this.aliveCount;
    frame.aliveCount = this.aliveCount;
    this.checkForClear();
    return frame;
  }

  notifyEnemyKilled(enemy: EnemyBase): void {
    if (!this.enemies.includes(enemy)) return;
    this.run.enemiesRemaining = this.aliveCount;
    this.checkForClear();
  }

  clear(): void {
    for (const enemy of this.enemies) this.root.remove(enemy.root);
    this.enemies.length = 0;
    this.run.enemiesRemaining = 0;
    this.clearedEmitted = false;
  }

  private createDifficulty(): EncounterDifficulty {
    const worldFloorScale = 1 + (this.run.world - 1) * 0.1 + (this.run.floor - 1) * 0.045;
    const baseCount = this.run.isBossFloor() ? 2 + Math.floor(this.run.world * 0.5) : 2 + this.run.floor;
    return {
      hpMult: worldFloorScale * this.combatMods.enemyHpMult,
      damageMult: worldFloorScale * this.combatMods.enemyDamageMult,
      projectileSpeedMult: this.combatMods.enemyProjectileSpeedMult,
      spawnCount: Math.max(1, Math.round(baseCount * this.combatMods.enemySpawnRateMult)),
      eliteSpawnChance: Math.min(0.65, 0.05 + this.run.world * 0.025 + this.combatMods.eliteSpawnChanceAdd),
    };
  }

  private spawnEnemy(kind: EnemyKind, position: THREE.Vector3): EnemyBase {
    const actualKind = this.promoteElite(kind);
    const enemy = this.createEnemy(actualKind, position);
    enemy.hp = Math.max(1, enemy.config.maxHp * this.difficulty.hpMult);
    enemy.root.userData.maxHp = enemy.hp;
    enemy.root.userData.damageMult = this.difficulty.damageMult;
    this.enemies.push(enemy);
    this.root.add(enemy.root);
    this.run.enemiesRemaining = this.aliveCount;
    return enemy;
  }

  private createEnemy(kind: EnemyKind, position: THREE.Vector3): EnemyBase {
    if (kind === 'meleeKnightAdd') return new MeleeKnightAdd(position);
    if (kind === 'necromancer') return new Necromancer(position);
    if (kind === 'skeletonMage') return new SkeletonMage(position);
    if (kind === 'rogueSkeleton') return new RogueSkeleton(position);
    if (kind === 'skeletonGolem') return new SkeletonGolem(position);
    return new MinionSkeleton(position);
  }

  private promoteElite(kind: EnemyKind): EnemyKind {
    if (kind === 'skeletonGolem' || kind === 'necromancer') return kind;
    if (this.rng() > this.difficulty.eliteSpawnChance) return kind;
    return this.run.world >= 3 ? 'skeletonGolem' : 'meleeKnightAdd';
  }

  private pickEnemyKind(world: WorldId, floor: number): EnemyKind {
    const weights = this.enemyWeights(world, floor);
    const total = weights.reduce((sum, entry) => sum + entry.weight, 0);
    let roll = this.rng() * total;
    for (const entry of weights) {
      roll -= entry.weight;
      if (roll <= 0) return entry.kind;
    }
    return weights[weights.length - 1]!.kind;
  }

  private enemyWeights(world: WorldId, floor: number): WeightedEnemy[] {
    if (world === 1) {
      return [
        { kind: 'minionSkeleton', weight: 4 },
        { kind: 'meleeKnightAdd', weight: 2 + floor * 0.35 },
        { kind: 'skeletonMage', weight: floor >= 3 ? 1.6 : 0.35 },
      ];
    }
    if (world === 2) {
      return [
        { kind: 'rogueSkeleton', weight: 2.4 },
        { kind: 'skeletonMage', weight: 2.2 },
        { kind: 'necromancer', weight: floor >= 3 ? 1.5 : 0.7 },
        { kind: 'minionSkeleton', weight: 1.2 },
      ];
    }
    if (world === 3) {
      return [
        { kind: 'meleeKnightAdd', weight: 2.1 },
        { kind: 'skeletonGolem', weight: floor >= 4 ? 1.3 : 0.6 },
        { kind: 'rogueSkeleton', weight: 1.6 },
        { kind: 'skeletonMage', weight: 1.2 },
      ];
    }
    return [
      { kind: 'skeletonGolem', weight: 1.5 },
      { kind: 'necromancer', weight: 1.4 },
      { kind: 'rogueSkeleton', weight: 1.2 },
      { kind: 'skeletonMage', weight: 1.2 },
      { kind: 'meleeKnightAdd', weight: 1.0 },
    ];
  }

  private applyDifficultyToEvents(events: EnemyFrameEvents): void {
    for (const melee of events.melee) {
      melee.damage *= this.difficulty.damageMult;
      melee.knockback *= Math.min(1.25, this.difficulty.damageMult);
    }
    for (const contact of events.contacts) {
      contact.damage *= this.difficulty.damageMult;
      contact.knockback *= Math.min(1.25, this.difficulty.damageMult);
    }
    for (const projectile of events.projectiles) {
      projectile.spec.speed *= this.difficulty.projectileSpeedMult;
      projectile.spec.payload = {
        ...projectile.spec.payload,
        damage: projectile.spec.payload.damage * this.difficulty.damageMult,
      };
    }
  }

  private createFrame(): EncounterFrame {
    return {
      melee: [],
      projectiles: [],
      summons: [],
      contacts: [],
      deaths: [],
      aliveCount: this.aliveCount,
      spawned: [],
    };
  }

  private mergeFrame(target: EncounterFrame, source: EnemyFrameEvents): void {
    target.melee.push(...source.melee);
    target.projectiles.push(...source.projectiles);
    target.summons.push(...source.summons);
    target.contacts.push(...source.contacts);
    target.deaths.push(...source.deaths);
  }

  private checkForClear(): void {
    if (this.clearedEmitted || this.aliveCount > 0) return;
    this.clearedEmitted = true;
    bus.emit<FloorClearedPayload>(Events.FLOOR_CLEARED, {
      world: this.run.world,
      floor: this.run.floor,
      bossFloor: this.run.isBossFloor(),
    });
  }
}
