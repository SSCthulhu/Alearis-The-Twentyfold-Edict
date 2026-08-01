import * as THREE from 'three';
import { buildEnemyFigure, type FigureColors, type ProceduralFigure } from '../actors/ProceduralFigure';
import type { ProjectilePatternSpec } from '../combat/Projectiles';
import { StatusEffectController } from '../combat/StatusEffects';
import {
  DEFAULT_ENEMY_COLORS,
  getEnemyConfig,
  type EnemyAiState,
  type EnemyAttackConfig,
  type EnemyConfig,
  type EnemyDamagePacket,
  type EnemyDamageResult,
  type EnemyKind,
  type PlatformSpan,
} from './EnemyTypes';

export interface EnemyAiContext {
  playerPosition: THREE.Vector3;
  platforms: readonly PlatformSpan[];
  rng: () => number;
  playerHurtboxRadius?: number;
  lineOfSight?: (from: THREE.Vector3, to: THREE.Vector3) => boolean;
}

export interface EnemyMeleeEvent {
  type: 'melee';
  enemy: EnemyBase;
  origin: THREE.Vector3;
  facing: number;
  range: number;
  arc: number;
  damage: number;
  knockback: number;
  telegraphTime: number;
}

export interface EnemyProjectileEvent {
  type: 'projectile';
  enemy: EnemyBase;
  origin: THREE.Vector3;
  aim: THREE.Vector3;
  spec: ProjectilePatternSpec;
  telegraphTime: number;
}

export interface EnemySummonEvent {
  type: 'summon';
  enemy: EnemyBase;
  kind: EnemyKind;
  position: THREE.Vector3;
}

export interface EnemyContactEvent {
  type: 'contact';
  enemy: EnemyBase;
  damage: number;
  knockback: number;
}

export interface EnemyFrameEvents {
  melee: EnemyMeleeEvent[];
  projectiles: EnemyProjectileEvent[];
  summons: EnemySummonEvent[];
  contacts: EnemyContactEvent[];
  deaths: EnemyBase[];
}

export class EnemyBase {
  readonly kind: EnemyKind;
  readonly config: EnemyConfig;
  readonly figure: ProceduralFigure;
  readonly root: THREE.Group;
  readonly statuses: StatusEffectController;
  hp: number;
  state: EnemyAiState = 'patrol';

  protected facing = 1;
  protected patrolDir = 1;
  protected stateTimer = 0;
  protected attackCooldownRemaining = 0.2;
  protected contactCooldownRemaining = 0;
  protected currentPlatform: PlatformSpan | null = null;
  protected deathT = 0;

  constructor(kind: EnemyKind, position = new THREE.Vector3(), colors: FigureColors = {}) {
    this.kind = kind;
    this.config = getEnemyConfig(kind);
    this.hp = this.config.maxHp;
    this.statuses = new StatusEffectController();
    this.figure = buildEnemyFigure(kind, { ...DEFAULT_ENEMY_COLORS[kind], ...colors });
    this.root = this.figure.root;
    this.root.position.copy(position);
    this.root.userData.enemy = this;
    this.root.userData.kind = kind;
    this.root.userData.elite = this.config.elite;
    this.setFacing(this.patrolDir);
  }

  get alive(): boolean {
    return this.state !== 'dead';
  }

  get elite(): boolean {
    return this.config.elite;
  }

  get hpRatio(): number {
    return this.hp / this.config.maxHp;
  }

  update(dt: number, ctx: EnemyAiContext): EnemyFrameEvents {
    const events = this.createFrameEvents();
    this.attackCooldownRemaining = Math.max(0, this.attackCooldownRemaining - dt);
    this.contactCooldownRemaining = Math.max(0, this.contactCooldownRemaining - dt);

    if (this.state === 'dead') {
      this.deathT = Math.min(1, this.deathT + dt * 1.6);
      this.figure.updateAnim(dt, { name: 'death', deathT: this.deathT });
      return events;
    }

    for (const tick of this.statuses.update(dt)) {
      this.applyRawDamage(tick.amount);
      if (this.hp <= 0) break;
    }

    if (this.hp <= 0) {
      this.enterDeath(events);
      this.figure.updateAnim(dt, { name: 'death', deathT: this.deathT });
      return events;
    }

    this.currentPlatform = this.findPlatform(ctx.platforms);
    this.emitContactIfOverlapping(ctx, events);

    const modifiers = this.statuses.modifiers();
    if (modifiers.stunned) {
      this.state = 'stunned';
      this.figure.updateAnim(dt, { name: 'hurt', intensity: 0.9 });
      return events;
    }
    if (this.state === 'stunned') this.transitionTo('chase');

    const playerDistance = this.root.position.distanceTo(ctx.playerPosition);
    const canSeePlayer = this.canSeePlayer(ctx, playerDistance);

    if (this.state === 'idle' || this.state === 'patrol') {
      if (canSeePlayer) {
        this.transitionTo('aggroDelay', this.config.aggroDelay);
      } else {
        this.patrol(dt, modifiers.movementScale);
      }
    } else if (this.state === 'aggroDelay') {
      this.faceToward(ctx.playerPosition.x);
      this.stateTimer -= dt;
      if (!canSeePlayer) this.transitionTo('patrol');
      if (this.stateTimer <= 0) this.transitionTo('chase');
    } else if (this.state === 'chase') {
      this.faceToward(ctx.playerPosition.x);
      if (playerDistance > this.config.deaggroRange) {
        this.transitionTo('patrol');
      } else if (playerDistance <= this.config.attackRange && this.attackCooldownRemaining <= 0) {
        this.transitionTo('windup', this.config.windup);
      } else if (playerDistance > this.config.stopRange) {
        this.moveHorizontal(this.facing * this.config.chaseSpeed * modifiers.movementScale * dt);
      }
    } else if (this.state === 'windup') {
      this.faceToward(ctx.playerPosition.x);
      this.stateTimer -= dt;
      if (this.stateTimer <= 0) {
        this.appendAttackEvents(ctx, events);
        this.attackCooldownRemaining = this.config.attackCooldown;
        this.transitionTo('recovery', this.config.recovery);
      }
    } else if (this.state === 'recovery') {
      this.stateTimer -= dt;
      if (this.stateTimer <= 0) this.transitionTo(canSeePlayer ? 'chase' : 'patrol');
    }

    this.updateFigureAnimation(dt, playerDistance);
    return events;
  }

  takeDamage(packet: EnemyDamagePacket): EnemyDamageResult {
    if (this.state === 'dead') return { applied: 0, killed: false, ignored: true, reason: 'dead' };

    if (this.shouldIgnoreDamage(packet)) {
      return { applied: 0, killed: false, ignored: true, reason: 'ranged_immune_unless_close' };
    }

    if (packet.status && packet.statusDuration && packet.statusDuration > 0) {
      this.statuses.apply({ id: packet.status, duration: packet.statusDuration, sourceId: packet.source });
    }

    const amount = Math.max(0, packet.amount * this.statuses.modifiers().damageTakenScale);
    this.applyRawDamage(amount);
    if (packet.knockback && packet.sourcePosition) this.applyKnockback(packet.sourcePosition, packet.knockback);

    if (this.hp <= 0) {
      this.transitionTo('dead');
      return { applied: amount, killed: true, ignored: false };
    }

    if (this.state !== 'windup' && this.state !== 'recovery') this.transitionTo('chase');
    return { applied: amount, killed: false, ignored: false };
  }

  protected createFrameEvents(): EnemyFrameEvents {
    return { melee: [], projectiles: [], summons: [], contacts: [], deaths: [] };
  }

  protected appendAttackEvents(ctx: EnemyAiContext, events: EnemyFrameEvents): void {
    if (this.config.projectile && this.root.position.distanceTo(ctx.playerPosition) > this.config.meleeRange * 1.2) {
      const projectile = this.createProjectileEvent(this.config.projectile, ctx.playerPosition);
      if (projectile) events.projectiles.push(projectile);
      return;
    }

    events.melee.push({
      type: 'melee',
      enemy: this,
      origin: this.root.position.clone().add(new THREE.Vector3(this.facing * 0.42, 1.05, 0)),
      facing: this.facing,
      range: this.config.meleeRange,
      arc: this.config.meleeArc,
      damage: this.config.meleeDamage,
      knockback: 1.2,
      telegraphTime: this.config.windup,
    });
  }

  protected createProjectileEvent(
    attack: EnemyAttackConfig,
    targetPosition: THREE.Vector3,
    originOffset = new THREE.Vector3(0.42, 1.2, 0),
  ): EnemyProjectileEvent | null {
    const origin = this.root.position.clone().add(new THREE.Vector3(this.facing * originOffset.x, originOffset.y, originOffset.z));
    const aim = targetPosition.clone().sub(origin);
    if (aim.lengthSq() < 0.0001) return null;
    const payload = { ...attack.payload };
    if (attack.status) payload.status = attack.status;
    return {
      type: 'projectile',
      enemy: this,
      origin,
      aim: aim.normalize(),
      spec: {
        pattern: attack.pattern,
        count: attack.count,
        speed: attack.speed,
        lifetime: attack.lifetime,
        payload,
        spread: attack.spread,
        radius: attack.radius,
        scale: attack.scale,
        color: attack.color,
      },
      telegraphTime: this.config.windup,
    };
  }

  protected emitSummon(events: EnemyFrameEvents, kind: EnemyKind, position: THREE.Vector3): void {
    events.summons.push({ type: 'summon', enemy: this, kind, position });
  }

  protected transitionTo(state: EnemyAiState, timer = 0): void {
    this.state = state;
    this.stateTimer = timer;
  }

  protected setFacing(dir: number): void {
    this.facing = dir < 0 ? -1 : 1;
    this.figure.setFacing(this.facing);
  }

  protected faceToward(x: number): void {
    this.setFacing(x >= this.root.position.x ? 1 : -1);
  }

  protected moveHorizontal(dx: number): void {
    if (Math.abs(dx) < 0.0001) return;
    const platform = this.currentPlatform;
    if (!platform) {
      this.root.position.x += dx;
      return;
    }

    const nextX = this.root.position.x + dx;
    const minX = platform.xMin + this.config.edgeMargin;
    const maxX = platform.xMax - this.config.edgeMargin;
    if (nextX <= minX) {
      this.root.position.x = minX;
      this.patrolDir = 1;
      this.setFacing(1);
    } else if (nextX >= maxX) {
      this.root.position.x = maxX;
      this.patrolDir = -1;
      this.setFacing(-1);
    } else {
      this.root.position.x = nextX;
    }
    this.root.position.y = platform.y;
  }

  protected applyRawDamage(amount: number): void {
    this.hp = Math.max(0, this.hp - amount);
  }

  private patrol(dt: number, movementScale: number): void {
    this.setFacing(this.patrolDir);
    this.moveHorizontal(this.patrolDir * this.config.patrolSpeed * movementScale * dt);
  }

  private canSeePlayer(ctx: EnemyAiContext, distance: number): boolean {
    if (distance > this.config.aggroRange) return false;
    if (ctx.lineOfSight && !ctx.lineOfSight(this.root.position, ctx.playerPosition)) return false;
    const platform = this.currentPlatform;
    if (!platform) return true;
    const playerOnSamePlatform = ctx.playerPosition.x >= platform.xMin && ctx.playerPosition.x <= platform.xMax;
    const playerCloseVertically = Math.abs(ctx.playerPosition.y - platform.y) < 1.6;
    return playerOnSamePlatform && playerCloseVertically;
  }

  private findPlatform(platforms: readonly PlatformSpan[]): PlatformSpan | null {
    let best: PlatformSpan | null = null;
    let bestDistance = Number.POSITIVE_INFINITY;
    for (const platform of platforms) {
      const insideX = this.root.position.x >= platform.xMin - 0.35 && this.root.position.x <= platform.xMax + 0.35;
      if (!insideX) continue;
      const yDistance = Math.abs(this.root.position.y - platform.y);
      if (yDistance < bestDistance && yDistance < 1.2) {
        best = platform;
        bestDistance = yDistance;
      }
    }
    return best;
  }

  private emitContactIfOverlapping(ctx: EnemyAiContext, events: EnemyFrameEvents): void {
    const radius = this.config.contactRadius + (ctx.playerHurtboxRadius ?? 0.35);
    if (this.contactCooldownRemaining > 0 || this.root.position.distanceTo(ctx.playerPosition) > radius) return;
    this.contactCooldownRemaining = this.config.contactCooldown;
    events.contacts.push({
      type: 'contact',
      enemy: this,
      damage: this.config.contactDamage,
      knockback: 0.9,
    });
  }

  private shouldIgnoreDamage(packet: EnemyDamagePacket): boolean {
    if (!this.config.rangedImmuneUnlessClose) return false;
    if (packet.type !== 'ranged' && packet.type !== 'projectile') return false;
    if (!packet.sourcePosition) return true;
    const closeRange = this.config.rangedCloseRange ?? 2.2;
    return packet.sourcePosition.distanceTo(this.root.position) > closeRange;
  }

  private applyKnockback(sourcePosition: THREE.Vector3, strength: number): void {
    const dir = this.root.position.x >= sourcePosition.x ? 1 : -1;
    this.moveHorizontal(dir * strength * 0.18);
  }

  private enterDeath(events: EnemyFrameEvents): void {
    this.transitionTo('dead');
    this.deathT = 0;
    this.statuses.clear();
    events.deaths.push(this);
  }

  private updateFigureAnimation(dt: number, playerDistance: number): void {
    if (this.state === 'windup') {
      const attackT = 1 - this.stateTimer / Math.max(this.config.windup, 0.01);
      this.figure.updateAnim(dt, {
        name: this.config.projectile && playerDistance > this.config.meleeRange ? 'cast' : 'attack',
        attackT,
      });
    } else if (this.state === 'chase' || this.state === 'patrol') {
      const speed = this.state === 'chase' ? this.config.chaseSpeed : this.config.patrolSpeed;
      this.figure.updateAnim(dt, { name: 'walk', speed });
    } else if (this.state === 'recovery') {
      this.figure.updateAnim(dt, { name: 'idle', intensity: 0.65 });
    } else {
      this.figure.updateAnim(dt, { name: 'idle' });
    }
  }
}
