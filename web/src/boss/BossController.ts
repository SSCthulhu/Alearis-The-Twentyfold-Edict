import * as THREE from 'three';
import type { DamageInfo } from '../core/types';
import type { RunState } from '../core/RunState';
import type { AscensionDeliveryEvent } from './AscensionCharge';
import type { BossIdentity, BossPhaseGate } from './BossIdentities';
import {
  emitPatternRecipe,
  getPatternRecipe,
  SimpleProjectilePool,
  type MinimalProjectileSystem,
  type ProjectileTarget,
  type RngFn,
} from './BulletPatterns';

export type BossEncounterState = 'ASCENT' | 'WAITING_FOR_ORB' | 'DPS_WINDOW' | 'PHASE_GATE' | 'DEFEATED';

export interface BossCastBar {
  readonly name: string;
  readonly durationSec: number;
  readonly elapsedSec: number;
  readonly progress: number;
  readonly scheduleId: string | null;
}

export interface BossAddSpawnEvent {
  readonly identity: BossIdentity;
  readonly cycleIndex: number;
  readonly budget: number;
  readonly reason: 'cycle' | 'phase_gate' | 'orb_drop';
}

export interface BossDamageResult {
  readonly rawAmount: number;
  readonly appliedAmount: number;
  readonly hp: number;
  readonly hpRatio: number;
  readonly vulnerable: boolean;
  readonly defeated: boolean;
}

export interface BossPhaseGateEvent {
  readonly identity: BossIdentity;
  readonly gate: BossPhaseGate;
  readonly cycleIndex: number;
}

export interface BossDpsWindowEvent {
  readonly identity: BossIdentity;
  readonly cycleIndex: number;
  readonly durationSec: number;
  readonly ascendantCoreBonusApplied: boolean;
}

export interface BossProjectileEvent {
  readonly identity: BossIdentity;
  readonly scheduleId: string;
  readonly cycleIndex: number;
  readonly state: BossEncounterState;
}

export interface BossTelegraphEvent {
  readonly identity: BossIdentity;
  readonly scheduleId: string;
  readonly durationSec: number;
  readonly cycleIndex: number;
  readonly state: BossEncounterState;
}

export interface BossControllerOptions {
  readonly identity: BossIdentity;
  readonly runState: RunState;
  readonly projectileSystem?: MinimalProjectileSystem;
  readonly projectileTarget?: ProjectileTarget;
  readonly getProjectileOrigin?: () => THREE.Vector3;
  readonly ascentDurationSec?: number;
  readonly baseProjectileIntervalSec?: number;
  readonly autoUpdateProjectiles?: boolean;
  /** Seconds a ground telegraph shows before a pattern fires. Clamped to >= 0.5s. */
  readonly telegraphSec?: number;
  readonly onTelegraph?: (event: BossTelegraphEvent) => void;
  readonly onAddSpawn?: (event: BossAddSpawnEvent) => void;
  readonly onPhaseGate?: (event: BossPhaseGateEvent) => void;
  readonly onCastStarted?: (cast: BossCastBar) => void;
  readonly onCastCompleted?: (cast: BossCastBar) => void;
  readonly onDpsWindowStarted?: (event: BossDpsWindowEvent) => void;
  readonly onDpsWindowEnded?: (event: BossDpsWindowEvent) => void;
  readonly onProjectilePattern?: (event: BossProjectileEvent) => void;
  readonly onDefeated?: (identity: BossIdentity) => void;
}

interface MutableCastBar {
  name: string;
  durationSec: number;
  elapsedSec: number;
  scheduleId: string | null;
}

interface PendingPattern {
  scheduleId: string;
  remainingSec: number;
}

export class BossController {
  readonly identity: BossIdentity;
  readonly runState: RunState;
  readonly projectileSystem: MinimalProjectileSystem;

  state: BossEncounterState = 'ASCENT';
  hp: number;
  cycleIndex = 0;

  private readonly projectileTarget?: ProjectileTarget;
  private readonly getProjectileOrigin: () => THREE.Vector3;
  private readonly ascentDurationSec: number;
  private readonly baseProjectileIntervalSec: number;
  private readonly autoUpdateProjectiles: boolean;
  private readonly telegraphSec: number;
  private readonly onTelegraph?: (event: BossTelegraphEvent) => void;
  private readonly onAddSpawn?: (event: BossAddSpawnEvent) => void;
  private readonly onPhaseGate?: (event: BossPhaseGateEvent) => void;
  private readonly onCastStarted?: (cast: BossCastBar) => void;
  private readonly onCastCompleted?: (cast: BossCastBar) => void;
  private readonly onDpsWindowStarted?: (event: BossDpsWindowEvent) => void;
  private readonly onDpsWindowEnded?: (event: BossDpsWindowEvent) => void;
  private readonly onProjectilePattern?: (event: BossProjectileEvent) => void;
  private readonly onDefeated?: (identity: BossIdentity) => void;
  private projectileRng: RngFn;
  private projectileCooldownSec = 0;
  private pendingPattern: PendingPattern | null = null;
  private castBar: MutableCastBar | null = null;
  private dpsWindowRemainingSec = 0;
  private dpsWindowDurationSec = 0;
  private dpsWindowAscendantBonusApplied = false;
  private pendingGate: BossPhaseGate | null = null;
  private triggeredGateIndexes = new Set<number>();
  private addsSpawnedThisCycle = false;
  private patternCursor = 0;

  constructor(options: BossControllerOptions) {
    this.identity = options.identity;
    this.runState = options.runState;
    this.projectileSystem = options.projectileSystem ?? new SimpleProjectilePool();
    this.projectileTarget = options.projectileTarget;
    this.getProjectileOrigin = options.getProjectileOrigin ?? (() => new THREE.Vector3(0, 0, 0));
    this.ascentDurationSec = options.ascentDurationSec ?? 4.5;
    this.baseProjectileIntervalSec = options.baseProjectileIntervalSec ?? 3.2;
    this.autoUpdateProjectiles = options.autoUpdateProjectiles ?? true;
    this.telegraphSec = Math.max(0.5, options.telegraphSec ?? 0.7);
    this.onTelegraph = options.onTelegraph;
    this.onAddSpawn = options.onAddSpawn;
    this.onPhaseGate = options.onPhaseGate;
    this.onCastStarted = options.onCastStarted;
    this.onCastCompleted = options.onCastCompleted;
    this.onDpsWindowStarted = options.onDpsWindowStarted;
    this.onDpsWindowEnded = options.onDpsWindowEnded;
    this.onProjectilePattern = options.onProjectilePattern;
    this.onDefeated = options.onDefeated;

    this.hp = this.identity.maxHp;
    this.projectileRng = this.createProjectileRng(0);
    this.beginAscent();
  }

  update(deltaSec: number): void {
    if (deltaSec <= 0 || this.state === 'DEFEATED') return;

    if (this.autoUpdateProjectiles) this.projectileSystem.update(deltaSec);
    this.updateCast(deltaSec);

    if (this.state === 'DPS_WINDOW') {
      this.dpsWindowRemainingSec = Math.max(0, this.dpsWindowRemainingSec - deltaSec);
      if (this.dpsWindowRemainingSec <= 0) this.endDpsWindow();
    }

    this.updatePendingPattern(deltaSec);
    this.updateProjectileSchedule(deltaSec);
  }

  handleAscensionDelivery(event: AscensionDeliveryEvent): void {
    if (this.state === 'DEFEATED') return;
    this.beginDpsWindow(event.dpsWindowSeconds, event.ascendantCoreBonusApplied);
  }

  notifyOrbDropped(): void {
    if (this.state === 'DEFEATED') return;
    this.spawnAdds('orb_drop', Math.max(2, Math.ceil(this.identity.baseAddBudget * 0.45)));
  }

  takeDamage(input: DamageInfo | number): BossDamageResult {
    const rawAmount = typeof input === 'number' ? input : input.amount;
    if (rawAmount <= 0 || this.state === 'DEFEATED') {
      return this.damageResult(rawAmount, 0, this.isVulnerable(), false);
    }

    const vulnerable = this.isVulnerable();
    const multiplier = this.damageMultiplierForCurrentState();
    const appliedAmount = Math.min(this.hp, rawAmount * multiplier);
    this.hp = Math.max(0, this.hp - appliedAmount);

    if (this.hp <= 0) {
      this.defeat();
      return this.damageResult(rawAmount, appliedAmount, vulnerable, true);
    }

    this.checkPhaseGates();
    return this.damageResult(rawAmount, appliedAmount, vulnerable, false);
  }

  get hpRatio(): number {
    return this.hp / this.identity.maxHp;
  }

  get dpsWindowProgress(): number {
    if (this.dpsWindowDurationSec <= 0) return 0;
    return 1 - this.dpsWindowRemainingSec / this.dpsWindowDurationSec;
  }

  getCastBar(): BossCastBar | null {
    if (!this.castBar) return null;
    return this.publicCastBar(this.castBar);
  }

  isVulnerable(): boolean {
    return this.state === 'DPS_WINDOW';
  }

  forceProjectilePattern(scheduleId: string): void {
    this.emitProjectilePattern(scheduleId);
    this.projectileCooldownSec = this.projectileIntervalForState();
  }

  private beginAscent(): void {
    this.state = 'ASCENT';
    this.addsSpawnedThisCycle = false;
    this.pendingGate = null;
    this.projectileRng = this.createProjectileRng(this.cycleIndex);
    this.patternCursor = Math.floor(this.projectileRng() * this.identity.patternScheduleIds.length);
    this.projectileCooldownSec = 0.65;
    this.startCast('Ascension Shield', this.ascentDurationSec, null);
  }

  private enterWaitingForOrb(): void {
    this.state = 'WAITING_FOR_ORB';
    this.castBar = null;
    this.projectileCooldownSec = 0.35;
    if (!this.addsSpawnedThisCycle) {
      this.spawnAdds('cycle', this.identity.baseAddBudget + this.cycleIndex);
      this.addsSpawnedThisCycle = true;
    }
  }

  private beginDpsWindow(durationSec: number, ascendantCoreBonusApplied: boolean): void {
    this.state = 'DPS_WINDOW';
    this.castBar = null;
    this.pendingGate = null;
    this.dpsWindowDurationSec = Math.max(1, durationSec);
    this.dpsWindowRemainingSec = this.dpsWindowDurationSec;
    this.dpsWindowAscendantBonusApplied = ascendantCoreBonusApplied;
    this.projectileCooldownSec = this.projectileIntervalForState();
    this.onDpsWindowStarted?.({
      identity: this.identity,
      cycleIndex: this.cycleIndex,
      durationSec: this.dpsWindowDurationSec,
      ascendantCoreBonusApplied,
    });
  }

  private endDpsWindow(): void {
    const event: BossDpsWindowEvent = {
      identity: this.identity,
      cycleIndex: this.cycleIndex,
      durationSec: this.dpsWindowDurationSec,
      ascendantCoreBonusApplied: this.dpsWindowAscendantBonusApplied,
    };
    this.onDpsWindowEnded?.(event);
    this.cycleIndex += 1;
    this.beginAscent();
  }

  private beginPhaseGate(gate: BossPhaseGate): void {
    this.state = 'PHASE_GATE';
    this.pendingGate = gate;
    this.dpsWindowRemainingSec = 0;
    this.spawnAdds('phase_gate', this.identity.baseAddBudget + gate.addBudgetBonus + this.cycleIndex);
    this.startCast(gate.castName, gate.castDurationSec, gate.scheduleId);
    this.beginTelegraph(gate.scheduleId);
    this.onPhaseGate?.({ identity: this.identity, gate, cycleIndex: this.cycleIndex });
  }

  private completePhaseGate(): void {
    this.pendingGate = null;
    this.cycleIndex += 1;
    this.beginAscent();
  }

  private updateCast(deltaSec: number): void {
    if (!this.castBar) return;
    this.castBar.elapsedSec = Math.min(this.castBar.durationSec, this.castBar.elapsedSec + deltaSec);
    if (this.castBar.elapsedSec < this.castBar.durationSec) return;

    const completed = this.publicCastBar(this.castBar);
    this.onCastCompleted?.(completed);
    this.castBar = null;

    if (this.state === 'ASCENT') {
      this.enterWaitingForOrb();
    } else if (this.state === 'PHASE_GATE') {
      this.completePhaseGate();
    }
  }

  private startCast(name: string, durationSec: number, scheduleId: string | null): void {
    this.castBar = {
      name,
      durationSec,
      elapsedSec: 0,
      scheduleId,
    };
    this.onCastStarted?.(this.publicCastBar(this.castBar));
  }

  private updateProjectileSchedule(deltaSec: number): void {
    if (this.state === 'DEFEATED') return;
    this.projectileCooldownSec -= deltaSec;
    if (this.projectileCooldownSec > 0 || this.pendingPattern !== null) return;

    this.beginTelegraph(this.nextScheduleId());
    this.projectileCooldownSec = this.projectileIntervalForState();
  }

  /** Telegraph first: warn the player, then fire the pattern once the wind-up elapses. */
  private beginTelegraph(scheduleId: string): void {
    this.pendingPattern = { scheduleId, remainingSec: this.telegraphSec };
    this.onTelegraph?.({
      identity: this.identity,
      scheduleId,
      durationSec: this.telegraphSec,
      cycleIndex: this.cycleIndex,
      state: this.state,
    });
  }

  private updatePendingPattern(deltaSec: number): void {
    if (this.pendingPattern === null) return;
    this.pendingPattern.remainingSec -= deltaSec;
    if (this.pendingPattern.remainingSec > 0) return;
    const scheduleId = this.pendingPattern.scheduleId;
    this.pendingPattern = null;
    this.emitProjectilePattern(scheduleId);
  }

  private emitProjectilePattern(scheduleId: string): void {
    const recipe = getPatternRecipe(scheduleId, this.identity.difficultyTier);
    emitPatternRecipe(
      this.projectileSystem,
      recipe,
      this.getProjectileOrigin(),
      this.projectileRng,
      this.projectileTarget,
      this.projectileRng() * Math.PI * 2,
    );
    this.onProjectilePattern?.({
      identity: this.identity,
      scheduleId,
      cycleIndex: this.cycleIndex,
      state: this.state,
    });
  }

  private nextScheduleId(): string {
    if (this.pendingGate) return this.pendingGate.scheduleId;
    const schedules = this.identity.patternScheduleIds;
    const id = schedules[this.patternCursor % schedules.length]!;
    this.patternCursor += 1;
    return id;
  }

  private projectileIntervalForState(): number {
    const difficultyReduction = Math.min(1.15, (this.identity.difficultyTier - 1) * 0.13);
    const base = Math.max(1.25, this.baseProjectileIntervalSec - difficultyReduction);
    if (this.state === 'DPS_WINDOW') return base * 1.25;
    if (this.state === 'PHASE_GATE') return base * 0.65;
    return base;
  }

  private damageMultiplierForCurrentState(): number {
    if (this.state === 'DPS_WINDOW') return 1;
    if (this.state === 'PHASE_GATE') return 0;
    return this.identity.armorDuringAscent;
  }

  private checkPhaseGates(): void {
    for (let i = 0; i < this.identity.phaseGates.length; i++) {
      if (this.triggeredGateIndexes.has(i)) continue;
      const gate = this.identity.phaseGates[i]!;
      if (this.hpRatio > gate.hpRatio) continue;
      this.triggeredGateIndexes.add(i);
      this.beginPhaseGate(gate);
      return;
    }
  }

  private spawnAdds(reason: BossAddSpawnEvent['reason'], budget: number): void {
    this.onAddSpawn?.({
      identity: this.identity,
      cycleIndex: this.cycleIndex,
      budget,
      reason,
    });
  }

  private defeat(): void {
    this.state = 'DEFEATED';
    this.castBar = null;
    this.pendingGate = null;
    this.pendingPattern = null;
    this.projectileSystem.clear();
    this.onDefeated?.(this.identity);
  }

  private createProjectileRng(extra: number): RngFn {
    const identityOffset = this.identity.difficultyTier * 4096 + extra * 97;
    return this.runState.rng('boss_projectiles', identityOffset);
  }

  private publicCastBar(cast: MutableCastBar): BossCastBar {
    return {
      name: cast.name,
      durationSec: cast.durationSec,
      elapsedSec: cast.elapsedSec,
      progress: cast.durationSec <= 0 ? 1 : cast.elapsedSec / cast.durationSec,
      scheduleId: cast.scheduleId,
    };
  }

  private damageResult(
    rawAmount: number,
    appliedAmount: number,
    vulnerable: boolean,
    defeated: boolean,
  ): BossDamageResult {
    return {
      rawAmount,
      appliedAmount,
      hp: this.hp,
      hpRatio: this.hpRatio,
      vulnerable,
      defeated,
    };
  }
}
