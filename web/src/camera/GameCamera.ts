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

  update(dt: number, target: THREE.Vector3, world: WorldId, bounds?: AABB): void {
    if (this.cinematic) {
      this.updateCinematic(dt);
      return;
    }

    const trackX = world === 3 ? target.x : THREE.MathUtils.damp(this.focus.x, target.x * 0.38, 3.4, dt);
    this.focus.set(trackX, target.y + this.verticalOffset, 0);
    this.constrainFocus(bounds);

    this.desired.set(this.focus.x, this.focus.y, this.sideDistance);
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

  startBossReveal(playerPosition: THREE.Vector3, bossPosition: THREE.Vector3, duration = 2.35): void {
    this.cinematic = {
      mode: 'boss_reveal',
      elapsed: 0,
      duration,
      from: this.camera.position.clone(),
      target: bossPosition.clone().lerp(playerPosition, 0.22).add(new THREE.Vector3(0, 1.2, this.sideDistance * 0.84)),
      center: bossPosition.clone().add(new THREE.Vector3(0, 1.35, 0)),
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

  private constrainFocus(bounds?: AABB): void {
    if (!bounds) return;
    const marginX = 2.2;
    const marginY = 1.6;
    this.focus.x = THREE.MathUtils.clamp(this.focus.x, bounds.x + marginX, bounds.x + bounds.w - marginX);
    this.focus.y = THREE.MathUtils.clamp(this.focus.y, bounds.y + marginY, bounds.y + bounds.h - marginY);
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
