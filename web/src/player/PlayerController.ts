import * as THREE from 'three';
import type { ActorVisual } from '../actors/ActorVisual';
import { buildKayKitPlayer, canBuildKayKitPlayer } from '../actors/KayKitFigure';
import { buildPlayerFigure } from '../actors/ProceduralFigure';
import { bus, Events } from '../core/EventBus';
import type { RunState } from '../core/RunState';
import type { AABB, DamageInfo, Vec2 } from '../core/types';
import { baseCombatMods, getModifierCombatMods, type CombatMods } from '../dice/ModifierEffects';
import type { Arena, ArenaPlatform } from '../world/ArenaBuilder';
import { getClassDef } from './ClassDefs';
import type { InputSnapshot } from './Input';
import {
  DEFAULT_DOUBLE_JUMP_SPEED,
  DEFAULT_GRAVITY,
  DEFAULT_JUMP_SPEED,
  MAX_SAFE_GRAVITY_MULTIPLIER,
} from './JumpMath';
import { PlayerBuffs } from './PlayerBuffs';
import { PlayerCombat, type PlayerCombatEvent } from './PlayerCombat';
import { PlayerDebuffs, type PlayerDebuffTick } from './PlayerDebuffs';
import { PlayerHealth, type PlayerDamageResult } from './PlayerHealth';

export interface PlayerControllerStats {
  width: number;
  height: number;
  walkSpeed: number;
  sprintSpeed: number;
  sprintWarmup: number;
  airControl: number;
  jumpSpeed: number;
  doubleJumpSpeed: number;
  gravity: number;
  maxFallSpeed: number;
  coyoteTime: number;
  jumpBuffer: number;
  dashSpeed: number;
  dashDuration: number;
  dashIFrameDuration: number;
  perfectDodgeStart: number;
  perfectDodgeEnd: number;
  dashRechargeTime: number;
  maxDashCharges: number;
}

export interface PlayerFrame {
  position: THREE.Vector3;
  velocity: THREE.Vector3;
  grounded: boolean;
  facing: number;
  dashCharges: number;
  dashStarted: boolean;
  jumped: boolean;
  landed: boolean;
  combatEvents: PlayerCombatEvent[];
  debuffTicks: PlayerDebuffTick[];
}

export interface PlayerRelicModifiers {
  dashChargesBonus: number;
  moveSpeedMult: number;
  perfectWindowBonus: number;
  critChanceBonus: number;
}

interface DashState {
  elapsed: number;
  duration: number;
  direction: number;
}

const FIXED_PHYSICS_STEP = 1 / 120;
const MAX_PHYSICS_SUBSTEPS = 8;
const DASH_AIR_GRAVITY_SCALE = 0.35;
const JUMP_CUT_MULTIPLIER = 0.45;
const JUMP_CUT_MIN_SPEED = 1;
const GROUND_SNAP_DISTANCE = 0.1;
const COLLISION_EPSILON = 0.0001;

const BASE_STATS: PlayerControllerStats = {
  width: 0.66,
  height: 1.82,
  walkSpeed: 4.2,
  sprintSpeed: 6.15,
  sprintWarmup: 0.55,
  airControl: 0.72,
  jumpSpeed: DEFAULT_JUMP_SPEED,
  doubleJumpSpeed: DEFAULT_DOUBLE_JUMP_SPEED,
  gravity: DEFAULT_GRAVITY,
  maxFallSpeed: 18,
  coyoteTime: 0.14,
  jumpBuffer: 0.15,
  dashSpeed: 13.5,
  dashDuration: 0.28,
  dashIFrameDuration: 0.28,
  perfectDodgeStart: 0.08,
  perfectDodgeEnd: 0.26,
  dashRechargeTime: 3.5,
  maxDashCharges: 2,
};

export class PlayerController {
  readonly run: RunState;
  readonly root = new THREE.Group();
  readonly figure: ActorVisual;
  readonly buffs = new PlayerBuffs();
  readonly debuffs = new PlayerDebuffs();
  readonly health: PlayerHealth;
  readonly combat: PlayerCombat;
  readonly stats: PlayerControllerStats;
  readonly position = new THREE.Vector3();
  readonly velocity = new THREE.Vector3();
  facing = 1;
  grounded = false;
  private coyoteTimer = 0;
  private jumpBufferTimer = 0;
  private jumpsUsed = 0;
  private moveHeldTimer = 0;
  private dashCharges = BASE_STATS.maxDashCharges;
  private dashRechargeTimer = 0;
  private dashState: DashState | null = null;
  private damageTakenMult = 1;
  private moveSpeedMult = 1;
  private gravityMult = 1;
  private dashRecoveryMult = 1;
  private modifierMods: CombatMods = baseCombatMods();
  private councilMods: CombatMods = baseCombatMods();
  private relicMoveSpeedMult = 1;
  private relicPerfectWindowBonus = 0;
  private relicDashChargesBonus = 0;
  private readonly rng: () => number;
  private physicsAccumulator = 0;
  private jumpWasHeld = false;

  constructor(run: RunState, spawn: Vec2, stats: Partial<PlayerControllerStats> = {}) {
    this.run = run;
    const classDef = getClassDef(run.classId);
    this.stats = { ...BASE_STATS, ...classDef.movement, ...stats };
    this.figure = canBuildKayKitPlayer(run.classId)
      ? buildKayKitPlayer(run.classId)
      : buildPlayerFigure(run.classId);
    this.root.name = `player_${run.classId}_controller`;
    this.root.add(this.figure.root);
    this.position.set(spawn.x, spawn.y, 0);
    this.root.position.copy(this.position);
    this.rng = run.rng('encounter', 0x51a7);
    this.combat = new PlayerCombat(run.classId, this.buffs, this.rng);
    this.health = new PlayerHealth(this.buffs, this.debuffs, classDef.maxHealth);
    this.dashCharges = this.stats.maxDashCharges;
    this.applyRunModifiers();
  }

  get hitbox(): AABB {
    return {
      x: this.position.x - this.stats.width * 0.5,
      y: this.position.y,
      w: this.stats.width,
      h: this.stats.height,
    };
  }

  get dashChargeCount(): number {
    return this.dashCharges;
  }

  get invulnerable(): boolean {
    return this.dashState !== null && this.dashState.elapsed <= this.stats.dashIFrameDuration;
  }

  get inPerfectDodgeWindow(): boolean {
    if (!this.dashState) return false;
    return this.dashState.elapsed >= this.stats.perfectDodgeStart && this.dashState.elapsed <= this.stats.perfectDodgeEnd;
  }

  teleportTo(spawn: Vec2): void {
    this.position.set(spawn.x, spawn.y, 0);
    this.velocity.set(0, 0, 0);
    this.grounded = false;
    this.coyoteTimer = 0;
    this.jumpBufferTimer = 0;
    this.jumpsUsed = 0;
    this.physicsAccumulator = 0;
    this.jumpWasHeld = false;
    this.syncRoot();
  }

  applyRunModifiers(): void {
    this.modifierMods = getModifierCombatMods(this.run);
    this.updateEffectiveModifiers();
  }

  setCouncilCombatMods(mods: CombatMods): void {
    this.councilMods = mods;
    this.updateEffectiveModifiers();
  }

  setRelicModifiers(mods: PlayerRelicModifiers): void {
    const previousMaxCharges = this.stats.maxDashCharges;
    this.relicDashChargesBonus = Math.max(0, Math.trunc(mods.dashChargesBonus));
    this.relicMoveSpeedMult = Math.max(0.1, mods.moveSpeedMult);
    this.relicPerfectWindowBonus = Math.max(0, mods.perfectWindowBonus);
    this.stats.maxDashCharges = BASE_STATS.maxDashCharges + this.relicDashChargesBonus;
    if (this.stats.maxDashCharges > previousMaxCharges) {
      this.dashCharges = Math.min(this.stats.maxDashCharges, this.dashCharges + this.stats.maxDashCharges - previousMaxCharges);
    } else {
      this.dashCharges = Math.min(this.dashCharges, this.stats.maxDashCharges);
    }
    this.stats.perfectDodgeStart = Math.max(0.02, BASE_STATS.perfectDodgeStart - this.relicPerfectWindowBonus * 0.45);
    this.stats.perfectDodgeEnd = Math.min(this.stats.dashIFrameDuration, BASE_STATS.perfectDodgeEnd + this.relicPerfectWindowBonus);
    this.combat.setCritChanceBonus(mods.critChanceBonus);
    this.updateEffectiveModifiers();
  }

  update(dt: number, input: InputSnapshot, arena: Arena): PlayerFrame {
    const debuffTicks = this.updateStatuses(dt);
    const combatEvents: PlayerCombatEvent[] = [];
    this.combat.update(dt);
    this.updateDashRecharge(dt);

    if (this.health.alive) {
      this.captureJumpInput(input);
      const dashStarted = this.handleDashInput(input);
      let jumped = false;
      let landed = false;
      this.physicsAccumulator = Math.min(
        this.physicsAccumulator + Math.max(0, dt),
        FIXED_PHYSICS_STEP * MAX_PHYSICS_SUBSTEPS,
      );
      while (this.physicsAccumulator + COLLISION_EPSILON >= FIXED_PHYSICS_STEP) {
        const movementFrame = this.updateMovement(
          FIXED_PHYSICS_STEP,
          input,
          arena.platforms,
          arena.bounds,
        );
        jumped = jumped || movementFrame.jumped;
        landed = landed || movementFrame.landed;
        this.physicsAccumulator -= FIXED_PHYSICS_STEP;
      }
      this.handleCombatInput(input, combatEvents);
      this.updateFigure(dt);
      this.syncRoot();
      return {
        position: this.position.clone(),
        velocity: this.velocity.clone(),
        grounded: this.grounded,
        facing: this.facing,
        dashCharges: this.dashCharges,
        dashStarted,
        jumped,
        landed,
        combatEvents,
        debuffTicks,
      };
    }

    this.updateFigure(dt);
    this.syncRoot();
    return {
      position: this.position.clone(),
      velocity: this.velocity.clone(),
      grounded: this.grounded,
      facing: this.facing,
      dashCharges: this.dashCharges,
      dashStarted: false,
      jumped: false,
      landed: false,
      combatEvents,
      debuffTicks,
    };
  }

  /** Horizontal shove away from an attacker, dampened by knockback_resist_mult modifiers. */
  applyKnockback(sourceX: number, strength: number): void {
    if (strength <= 0) return;
    const resist = Math.max(0.1, this.modifierMods.playerKnockbackResistMult * this.councilMods.playerKnockbackResistMult);
    const direction = this.position.x >= sourceX ? 1 : -1;
    this.velocity.x += (direction * strength * 3.2) / resist;
  }

  takeDamage(info: DamageInfo): PlayerDamageResult {
    if (this.inPerfectDodgeWindow) {
      bus.emit(Events.PERFECT_DODGE, { source: info.source, evaded: true });
    }

    return this.health.takeDamage(
      {
        ...info,
        amount: info.amount * this.damageTakenMult,
      },
      {
        invulnerable: this.invulnerable,
        allowDodge: true,
        rng: this.rng,
      },
    );
  }

  private updateStatuses(dt: number): PlayerDebuffTick[] {
    this.buffs.update(dt);
    const ticks = this.debuffs.update(dt);
    for (const tick of ticks) {
      this.health.takeDamage({
        amount: tick.amount,
        source: 'enemy',
        crit: false,
        elemental: 'none',
      });
    }
    return ticks;
  }

  private captureJumpInput(input: InputSnapshot): void {
    if (input.jumpPressed) this.jumpBufferTimer = this.stats.jumpBuffer;
    if (this.jumpWasHeld && !input.jump && this.velocity.y > JUMP_CUT_MIN_SPEED) {
      this.velocity.y *= JUMP_CUT_MULTIPLIER;
    }
    this.jumpWasHeld = input.jump;
  }

  private handleDashInput(input: InputSnapshot): boolean {
    if (!input.dashPressed || this.dashCharges <= 0) return false;
    const direction = input.moveX !== 0 ? input.moveX : this.facing;
    this.startDash(direction);
    return true;
  }

  private startDash(direction: number): void {
    this.combat.cancelForDodge();
    this.dashCharges -= 1;
    const rollMult = this.combat.stats.rollTravelMult;
    this.dashState = {
      elapsed: 0,
      duration: this.stats.dashDuration,
      direction: direction >= 0 ? 1 : -1,
    };
    this.facing = this.dashState.direction;
    this.velocity.x = this.stats.dashSpeed * rollMult * this.dashState.direction;
  }

  private updateDashRecharge(dt: number): void {
    if (this.dashCharges >= this.stats.maxDashCharges) {
      this.dashRechargeTimer = 0;
      return;
    }
    this.dashRechargeTimer += dt * this.dashRecoveryMult;
    while (this.dashRechargeTimer >= this.stats.dashRechargeTime && this.dashCharges < this.stats.maxDashCharges) {
      this.dashRechargeTimer -= this.stats.dashRechargeTime;
      this.dashCharges += 1;
    }
  }

  private updateMovement(
    dt: number,
    input: InputSnapshot,
    platforms: readonly ArenaPlatform[],
    bounds: AABB,
  ): { jumped: boolean; landed: boolean } {
    if (input.moveX !== 0) {
      this.facing = input.moveX > 0 ? 1 : -1;
      this.moveHeldTimer += dt;
    } else {
      this.moveHeldTimer = 0;
    }

    this.coyoteTimer = this.grounded ? this.stats.coyoteTime : Math.max(0, this.coyoteTimer - dt);
    const jumped = this.jumpBufferTimer > 0 && this.consumeBufferedJump();

    this.updateHorizontalVelocity(dt, input);
    this.updateVerticalVelocity(dt);
    const landed = this.moveAndCollide(dt, platforms);
    this.clampToBounds(bounds);
    this.jumpBufferTimer = Math.max(0, this.jumpBufferTimer - dt);
    return { jumped, landed };
  }

  private updateHorizontalVelocity(dt: number, input: InputSnapshot): void {
    if (this.dashState) {
      this.dashState.elapsed += dt;
      this.velocity.x = this.dashState.direction * this.stats.dashSpeed * this.combat.stats.rollTravelMult;
      if (this.dashState.elapsed >= this.dashState.duration) this.dashState = null;
      return;
    }

    const sprinting = this.grounded && this.moveHeldTimer >= this.stats.sprintWarmup;
    const targetSpeed = (sprinting ? this.stats.sprintSpeed : this.stats.walkSpeed) * this.moveSpeedMult * this.buffs.moveSpeedMultiplier() * this.debuffs.moveSpeedMultiplier();
    const targetVelocity = input.moveX * targetSpeed;
    const control = this.grounded ? 1 : this.stats.airControl;
    this.velocity.x = THREE.MathUtils.damp(this.velocity.x, targetVelocity, 18 * control, dt);
  }

  private updateVerticalVelocity(dt: number): void {
    const gravityScale = this.dashState
      ? (this.grounded ? 0 : DASH_AIR_GRAVITY_SCALE)
      : 1;
    this.velocity.y -= this.stats.gravity * this.gravityMult * gravityScale * dt;
    this.velocity.y = Math.max(this.velocity.y, -this.stats.maxFallSpeed);
  }

  private consumeBufferedJump(): boolean {
    const canGroundJump = this.grounded || this.coyoteTimer > 0;
    const canDoubleJump = !canGroundJump && this.jumpsUsed < 1;
    if (!canGroundJump && !canDoubleJump) return false;

    this.velocity.y = canGroundJump ? this.stats.jumpSpeed : this.stats.doubleJumpSpeed;
    this.grounded = false;
    this.coyoteTimer = 0;
    this.jumpBufferTimer = 0;
    this.jumpsUsed = canGroundJump ? 0 : this.jumpsUsed + 1;
    return true;
  }

  private moveAndCollide(dt: number, platforms: readonly ArenaPlatform[]): boolean {
    const wasGrounded = this.grounded;
    this.grounded = false;
    this.position.x += this.velocity.x * dt;
    const previousY = this.position.y;
    this.position.y += this.velocity.y * dt;
    const landingTop = this.findLandingTop(previousY, platforms);
    if (landingTop === null) return false;

    this.position.y = landingTop;
    this.velocity.y = 0;
    this.grounded = true;
    this.jumpsUsed = 0;
    return !wasGrounded;
  }

  /**
   * Platforms are one-way. A descending foot sweep catches thin surfaces,
   * while rising players pass through undersides and edges without snagging.
   */
  private findLandingTop(previousY: number, platforms: readonly ArenaPlatform[]): number | null {
    if (this.velocity.y > 0) return null;

    let landingTop = Number.NEGATIVE_INFINITY;
    for (const platform of platforms) {
      if (!this.hasHorizontalOverlap(platform.aabb)) continue;
      const top = platform.topY;
      const crossedTop =
        previousY >= top - COLLISION_EPSILON &&
        this.position.y <= top + COLLISION_EPSILON;
      const withinSnapProbe =
        this.position.y >= top &&
        this.position.y - top <= GROUND_SNAP_DISTANCE;
      if (crossedTop || withinSnapProbe) landingTop = Math.max(landingTop, top);
    }
    return Number.isFinite(landingTop) ? landingTop : null;
  }

  private hasHorizontalOverlap(platform: AABB): boolean {
    const left = this.position.x - this.stats.width * 0.5;
    const right = this.position.x + this.stats.width * 0.5;
    return left < platform.x + platform.w && right > platform.x;
  }

  private clampToBounds(bounds: AABB): void {
    const minX = bounds.x + this.stats.width * 0.5;
    const maxX = bounds.x + bounds.w - this.stats.width * 0.5;
    this.position.x = THREE.MathUtils.clamp(this.position.x, minX, maxX);
    if (this.position.y < bounds.y - 6) {
      this.health.takeDamage({ amount: 20, source: 'hazard', crit: false, elemental: 'none' });
      this.position.y = bounds.y + 1;
      this.velocity.set(0, 0, 0);
      this.grounded = false;
    }
  }

  private handleCombatInput(input: InputSnapshot, out: PlayerCombatEvent[]): void {
    const origin = this.position.clone();
    if (input.lightPressed) {
      const event = this.combat.requestLight(origin, this.facing);
      if (event) out.push(event);
    }
    if (input.heavyPressed) {
      const event = this.combat.requestHeavy(origin, this.facing);
      if (event) out.push(event);
    }
    if (input.defendPressed) {
      const event = this.combat.requestDefend(origin, this.facing);
      if (event) out.push(event);
    }
    if (input.ultimatePressed) {
      const event = this.combat.requestUltimate(origin, this.facing);
      if (event) out.push(event);
    }
  }

  private updateFigure(dt: number): void {
    this.figure.setFacing(this.facing);
    if (!this.health.alive) {
      this.figure.updateAnim(dt, { name: 'death', deathT: 1 });
      return;
    }
    if (this.combat.busy) {
      this.figure.updateAnim(dt, this.combat.animationState());
      return;
    }
    if (!this.grounded) {
      this.figure.updateAnim(dt, {
        name: this.velocity.y >= 0 ? 'jump' : 'fall',
        intensity: this.dashState ? 1.2 : 0.7,
      });
      return;
    }
    const speed = Math.abs(this.velocity.x);
    if (speed > 0.25) {
      this.figure.updateAnim(dt, {
        name: speed > this.stats.walkSpeed * 1.12 ? 'run' : 'walk',
        speed: speed / this.stats.walkSpeed,
        intensity: 1,
      });
    } else {
      this.figure.updateAnim(dt, { name: 'idle' });
    }
  }

  private syncRoot(): void {
    this.root.position.copy(this.position);
  }

  private updateEffectiveModifiers(): void {
    this.moveSpeedMult = this.modifierMods.playerMoveSpeedMult * this.councilMods.playerMoveSpeedMult * this.relicMoveSpeedMult;
    // Arena validation assumes this cap: even stacked gravity effects retain
    // at least 3.2 units of default double-jump clearance over 2.35-unit steps.
    this.gravityMult = THREE.MathUtils.clamp(
      this.modifierMods.playerGravityMult * this.councilMods.playerGravityMult,
      0.1,
      MAX_SAFE_GRAVITY_MULTIPLIER,
    );
    this.damageTakenMult = this.modifierMods.playerDamageTakenMult * this.councilMods.playerDamageTakenMult;
    this.dashRecoveryMult = this.modifierMods.playerDashRecoveryMult * this.councilMods.playerDashRecoveryMult;
    this.combat.damageMult = this.modifierMods.playerDamageMult * this.councilMods.playerDamageMult;
    this.combat.cooldownRecoveryMult = this.modifierMods.playerCooldownRecoveryMult * this.councilMods.playerCooldownRecoveryMult;
    this.combat.attackSpeedMult = this.modifierMods.playerAttackSpeedMult * this.councilMods.playerAttackSpeedMult;
  }
}
