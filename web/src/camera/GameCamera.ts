import * as THREE from 'three';
import { bus, Events } from '../core/EventBus';
import type { WorldId, AABB } from '../core/types';

export interface GameCameraOptions {
  aspect: number;
  fov?: number;
  near?: number;
  far?: number;
  sideDistance?: number;
  verticalOffset?: number;
}

export interface CameraShake {
  intensity: number;
  duration: number;
}

type CinematicMode = 'none' | 'boss_reveal' | 'victory_orbit';

/** Half-height of a player figure, used when solving two-subject framing. */
const PLAYER_HALF_HEIGHT = 1.9;
/**
 * HUD safe areas as a fraction of frame height. These must be fractions, not
 * world distances: the boss bar always covers the same share of the screen, so
 * a constant in world units under-reserves exactly when the boss is tallest.
 */
const HUD_TOP_FRACTION = 0.19;
const HUD_BOTTOM_FRACTION = 0.07;
/** Share of a half-frame left usable once each HUD band is reserved. */
const TOP_USABLE = 1 - 2 * HUD_TOP_FRACTION;
const BOTTOM_USABLE = 1 - 2 * HUD_BOTTOM_FRACTION;

interface CinematicState {
  mode: CinematicMode;
  elapsed: number;
  duration: number;
  from: THREE.Vector3;
  target: THREE.Vector3;
  center: THREE.Vector3;
}

export class GameCamera {
  readonly camera: THREE.PerspectiveCamera;
  readonly focus = new THREE.Vector3();
  private readonly desired = new THREE.Vector3();
  private readonly shakeOffset = new THREE.Vector3();
  private readonly sideDistance: number;
  private readonly verticalOffset: number;
  private shakeTimer = 0;
  private shakeIntensity = 0;
  private cinematic: CinematicState | null = null;
  private unsubscribeShake: (() => void) | null = null;

  constructor(options: GameCameraOptions) {
    this.sideDistance = options.sideDistance ?? 16;
    this.verticalOffset = options.verticalOffset ?? 1.4;
    this.camera = new THREE.PerspectiveCamera(options.fov ?? 40, options.aspect, options.near ?? 0.1, options.far ?? 160);
    this.camera.name = 'locked_side_game_camera';
    this.camera.position.set(0, 3, this.sideDistance);
    this.camera.lookAt(0, 2, 0);
    this.unsubscribeShake = bus.on<CameraShake>(Events.SCREEN_SHAKE, (payload) => {
      this.shake(payload.intensity, payload.duration);
    });
  }

  dispose(): void {
    if (this.unsubscribeShake) this.unsubscribeShake();
    this.unsubscribeShake = null;
  }

  resize(aspect: number): void {
    this.camera.aspect = aspect;
    this.camera.updateProjectionMatrix();
  }

  update(
    dt: number,
    target: THREE.Vector3,
    world: WorldId,
    bounds?: AABB,
    secondary?: THREE.Vector3 | null,
    framingBias = 0.35,
    secondaryHalfHeight = 0,
  ): void {
    if (this.cinematic) {
      this.updateCinematic(dt);
      return;
    }

    let focusX = target.x;
    let focusY = target.y + this.verticalOffset;
    if (secondary) {
      focusX = THREE.MathUtils.lerp(target.x, secondary.x, framingBias);
      focusY = this.solveFramingCentre(target, secondary, secondaryHalfHeight);
    }

    const trackX = world === 3 ? focusX : THREE.MathUtils.damp(this.focus.x, focusX * (secondary ? 1 : 0.38), 3.4, dt);
    this.focus.set(trackX, focusY, 0);
    this.constrainFocus(bounds, secondary != null);

    const pullBack = secondary
      ? this.solvePullBack(target, secondary, secondaryHalfHeight)
      : this.sideDistance;
    this.desired.set(this.focus.x, this.focus.y, pullBack);
    this.camera.position.x = THREE.MathUtils.damp(this.camera.position.x, this.desired.x, 5.5, dt);
    this.camera.position.y = THREE.MathUtils.damp(this.camera.position.y, this.desired.y, 6.8, dt);
    this.camera.position.z = THREE.MathUtils.damp(this.camera.position.z, this.desired.z, 4.2, dt);

    this.applyShake(dt);
    this.camera.lookAt(this.focus.x, this.focus.y, 0);
  }

  shake(intensity: number, duration: number): void {
    this.shakeIntensity = Math.max(this.shakeIntensity, intensity);
    this.shakeTimer = Math.max(this.shakeTimer, duration);
  }

  /** `bossCenter` is the boss's visual centre, not its root, so tall bosses stay in frame. */
  startBossReveal(
    playerPosition: THREE.Vector3,
    bossCenter: THREE.Vector3,
    duration = 2.35,
    bossHalfHeight = 2.4,
  ): void {
    const distance = THREE.MathUtils.clamp(
      (bossHalfHeight * 1.25) / Math.tan(THREE.MathUtils.degToRad(this.camera.fov * 0.5)),
      this.sideDistance * 0.84,
      this.sideDistance * 1.9,
    );
    this.cinematic = {
      mode: 'boss_reveal',
      elapsed: 0,
      duration,
      from: this.camera.position.clone(),
      target: bossCenter.clone().lerp(playerPosition, 0.22).add(new THREE.Vector3(0, 0, distance)),
      center: bossCenter.clone(),
    };
  }

  startVictoryOrbit(center: THREE.Vector3, duration = 3.4): void {
    this.cinematic = {
      mode: 'victory_orbit',
      elapsed: 0,
      duration,
      from: this.camera.position.clone(),
      target: center.clone().add(new THREE.Vector3(0, 2.4, this.sideDistance * 0.72)),
      center: center.clone().add(new THREE.Vector3(0, 1.4, 0)),
    };
  }

  skipCinematic(): void {
    this.cinematic = null;
  }

  private updateCinematic(dt: number): void {
    if (!this.cinematic) return;
    const state = this.cinematic;
    state.elapsed += dt;
    const t = THREE.MathUtils.smoothstep(Math.min(1, state.elapsed / state.duration), 0, 1);

    if (state.mode === 'victory_orbit') {
      const angle = t * Math.PI * 1.25;
      const radius = this.sideDistance * 0.72;
      this.camera.position.set(
        state.center.x + Math.sin(angle) * 2.4,
        state.center.y + 1.8 + Math.sin(angle * 2) * 0.25,
        state.center.z + Math.cos(angle) * radius + radius,
      );
    } else {
      this.camera.position.lerpVectors(state.from, state.target, t);
    }

    this.focus.copy(state.center);
    this.applyShake(dt);
    this.camera.lookAt(state.center);

    if (state.elapsed >= state.duration) this.cinematic = null;
  }

  /**
   * Distance needed to keep both subjects inside the vertical field of view.
   * A fixed multiplier of `sideDistance` cannot do this: a tier-8 boss is more
   * than twice the height of a tier-1 boss, so any constant either clips the
   * big ones or leaves the small ones lost in empty sky.
   */
  private solvePullBack(
    target: THREE.Vector3,
    secondary: THREE.Vector3,
    secondaryHalfHeight: number,
  ): number {
    const top = Math.max(secondary.y + secondaryHalfHeight, target.y + PLAYER_HALF_HEIGHT);
    const bottom = Math.min(secondary.y - secondaryHalfHeight, target.y - PLAYER_HALF_HEIGHT);
    // Grow the half-span so each subject clears its side's HUD band. A crown
    // hidden behind the boss health bar still reads as clipped.
    const halfSpan = Math.max(
      (top - this.focus.y) / TOP_USABLE,
      (this.focus.y - bottom) / BOTTOM_USABLE,
    );
    const needed = halfSpan / Math.tan(THREE.MathUtils.degToRad(this.camera.fov * 0.5));
    return THREE.MathUtils.clamp(needed, this.sideDistance * 1.12, this.sideDistance * 3.9);
  }

  /**
   * Vertical centre that lets both subjects clear their own side's HUD band at
   * the smallest pull-back that can do it. A fixed bias lerp between the two
   * cannot: the reserved bands are asymmetric, so the point that balances them
   * is not the midpoint, and the error is worst exactly when the separation is
   * widest — player on the arena floor, boss overhead — which is where the
   * crown was being cut off.
   */
  private solveFramingCentre(
    target: THREE.Vector3,
    secondary: THREE.Vector3,
    secondaryHalfHeight: number,
  ): number {
    const top = Math.max(secondary.y + secondaryHalfHeight, target.y + PLAYER_HALF_HEIGHT);
    const bottom = Math.min(secondary.y - secondaryHalfHeight, target.y - PLAYER_HALF_HEIGHT);
    return (BOTTOM_USABLE * top + TOP_USABLE * bottom) / (TOP_USABLE + BOTTOM_USABLE);
  }

  private constrainFocus(bounds?: AABB, framingSecondary = false): void {
    if (!bounds) return;
    const marginX = 2.2;
    const marginY = 1.6;
    this.focus.x = THREE.MathUtils.clamp(this.focus.x, bounds.x + marginX, bounds.x + bounds.w - marginX);
    // A boss hovers above the platform the arena bounds were built from, so
    // clamping the focus to those bounds drags it back down and undoes the
    // framing solve. While a second subject is being framed the ceiling is
    // released; the floor still holds, so the camera never drops through the
    // arena.
    const ceiling = framingSecondary ? Infinity : bounds.y + bounds.h - marginY;
    this.focus.y = THREE.MathUtils.clamp(this.focus.y, bounds.y + marginY, ceiling);
  }

  private applyShake(dt: number): void {
    this.shakeOffset.set(0, 0, 0);
    if (this.shakeTimer > 0) {
      this.shakeTimer = Math.max(0, this.shakeTimer - dt);
      const falloff = this.shakeTimer <= 0 ? 0 : this.shakeTimer / Math.max(this.shakeTimer + dt, 0.001);
      const strength = this.shakeIntensity * falloff;
      this.shakeOffset.set((Math.random() - 0.5) * strength, (Math.random() - 0.5) * strength * 0.72, 0);
      this.camera.position.add(this.shakeOffset);
    } else {
      this.shakeIntensity = 0;
    }
  }
}
