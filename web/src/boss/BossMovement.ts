import * as THREE from 'three';
import type { Vec2 } from '../core/types';
import type { Arena } from '../world/ArenaBuilder';
import type { BossEncounterState } from './BossController';
import type { BossIdentity, BossMoveStyle } from './BossIdentities';

/**
 * Deterministic per-boss locomotion driven by identity.moveStyle.
 * The controller owns encounter state; this class only decides where the
 * visual should be each frame. During DPS windows the boss glides back to
 * its home perch so the player has a stable target.
 */

export type BossMovementBehavior = 'hop' | 'blink' | 'strafe';

export interface BossMovementOptions {
  readonly identity: BossIdentity;
  readonly arena: Arena;
  readonly rng: () => number;
  readonly home: Vec2;
  readonly onBlink?: (from: THREE.Vector3, to: THREE.Vector3) => void;
}

interface HopState {
  from: THREE.Vector3;
  to: THREE.Vector3;
  elapsed: number;
  duration: number;
  arcHeight: number;
}

const ANCHOR_HOVER = 0.9;
const MAX_ANCHORS = 5;
const HOME_GLIDE_LAMBDA = 4.5;

export function behaviorForMoveStyle(style: BossMoveStyle): BossMovementBehavior {
  switch (style) {
    case 'ice_platform_anchor':
      return 'hop';
    case 'portal_sub_arena':
      return 'blink';
    case 'horizontal_forge_lanes':
      return 'strafe';
    case 'fate_duelist':
      return 'hop';
    case 'choral_constellation':
      return 'strafe';
    case 'shadow_die_shift':
      return 'blink';
    case 'saintly_orbit':
      return 'strafe';
    case 'sovereign_twentyfold':
      return 'hop';
  }
}

export class BossMovement {
  readonly identity: BossIdentity;
  readonly behavior: BossMovementBehavior;
  readonly position = new THREE.Vector3();

  private readonly rng: () => number;
  private readonly home = new THREE.Vector3();
  private readonly anchors: THREE.Vector3[] = [];
  private readonly onBlink?: (from: THREE.Vector3, to: THREE.Vector3) => void;
  private anchorIndex = 0;
  private moveTimer: number;
  private hop: HopState | null = null;
  private strafePhase = 0;
  private readonly strafeCenterX: number;
  private readonly strafeHalfRange: number;

  constructor(options: BossMovementOptions) {
    this.identity = options.identity;
    this.behavior = behaviorForMoveStyle(options.identity.moveStyle);
    this.rng = options.rng;
    this.onBlink = options.onBlink;
    this.home.set(options.home.x, options.home.y, 0);
    this.position.copy(this.home);

    this.anchors = this.buildAnchors(options.arena);
    this.anchorIndex = this.nearestAnchorIndex(this.home);

    const bounds = options.arena.bounds;
    const margin = 3.2;
    this.strafeCenterX = bounds.x + bounds.w * 0.5;
    this.strafeHalfRange = Math.max(1.5, Math.min(6.5, bounds.w * 0.5 - margin));
    this.strafePhase = this.rng() * Math.PI * 2;
    this.moveTimer = this.nextMoveInterval();
  }

  /** Advances movement and returns the current position (same object each frame). */
  update(dt: number, state: BossEncounterState): THREE.Vector3 {
    if (dt <= 0 || state === 'DEFEATED') return this.position;

    if (state === 'DPS_WINDOW') {
      this.hop = null;
      this.position.x = THREE.MathUtils.damp(this.position.x, this.home.x, HOME_GLIDE_LAMBDA, dt);
      this.position.y = THREE.MathUtils.damp(this.position.y, this.home.y, HOME_GLIDE_LAMBDA, dt);
      return this.position;
    }

    const pace = state === 'PHASE_GATE' ? 1.45 : 1;
    if (this.behavior === 'strafe') {
      this.updateStrafe(dt * pace);
    } else if (this.behavior === 'hop') {
      this.updateHop(dt * pace);
    } else {
      this.updateBlink(dt * pace);
    }
    return this.position;
  }

  private updateStrafe(dt: number): void {
    this.strafePhase += dt * 0.62;
    this.position.x = this.strafeCenterX + Math.sin(this.strafePhase) * this.strafeHalfRange;
    this.position.y = THREE.MathUtils.damp(this.position.y, this.home.y, 3.5, dt);
  }

  private updateHop(dt: number): void {
    if (this.hop) {
      this.hop.elapsed += dt;
      const t = Math.min(1, this.hop.elapsed / this.hop.duration);
      this.position.lerpVectors(this.hop.from, this.hop.to, t);
      this.position.y += Math.sin(t * Math.PI) * this.hop.arcHeight;
      if (t >= 1) {
        this.position.copy(this.hop.to);
        this.hop = null;
        this.moveTimer = this.nextMoveInterval();
      }
      return;
    }

    this.moveTimer -= dt;
    if (this.moveTimer > 0 || this.anchors.length < 2) return;

    const target = this.pickNextAnchor();
    const distance = this.position.distanceTo(target);
    this.hop = {
      from: this.position.clone(),
      to: target.clone(),
      elapsed: 0,
      duration: 0.7 + Math.min(0.5, distance * 0.06),
      arcHeight: 1.4 + Math.min(1.4, distance * 0.14),
    };
  }

  private updateBlink(dt: number): void {
    this.moveTimer -= dt;
    if (this.moveTimer > 0 || this.anchors.length < 2) return;

    const from = this.position.clone();
    const target = this.pickNextAnchor();
    this.position.copy(target);
    this.moveTimer = this.nextMoveInterval();
    this.onBlink?.(from, target.clone());
  }

  private pickNextAnchor(): THREE.Vector3 {
    const count = this.anchors.length;
    let nextIndex = Math.floor(this.rng() * count) % count;
    if (nextIndex === this.anchorIndex) nextIndex = (nextIndex + 1) % count;
    this.anchorIndex = nextIndex;
    return this.anchors[nextIndex]!;
  }

  private nextMoveInterval(): number {
    const base = this.behavior === 'blink' ? 2.4 : 2.9;
    return base + this.rng() * 1.3;
  }

  private nearestAnchorIndex(point: THREE.Vector3): number {
    let best = 0;
    let bestDistance = Number.POSITIVE_INFINITY;
    for (let i = 0; i < this.anchors.length; i++) {
      const d = this.anchors[i]!.distanceToSquared(point);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  private buildAnchors(arena: Arena): THREE.Vector3[] {
    const home = this.home;
    const candidates = arena.platforms
      .map((platform) =>
        new THREE.Vector3(
          platform.aabb.x + platform.aabb.w * 0.5,
          platform.topY + ANCHOR_HOVER,
          0,
        ),
      )
      .sort((a, b) => a.distanceToSquared(home) - b.distanceToSquared(home))
      .slice(0, MAX_ANCHORS);
    if (candidates.length === 0) candidates.push(home.clone());
    return candidates;
  }
}
