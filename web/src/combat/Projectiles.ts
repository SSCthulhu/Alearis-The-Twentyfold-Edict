import * as THREE from 'three';
import { getSharedRamp } from '../render/CelMaterial';
import { perfBudget } from '../performance/Budget';
import type { StatusEffectId } from './StatusEffects';

export type ProjectileMovementMode = 'straight' | 'homing' | 'sine' | 'spiral';
export type ProjectilePattern = 'line' | 'radial' | 'cone' | 'spiral' | 'wave' | 'arc' | 'cross' | 'scatter';

export interface ProjectilePayload {
  damage: number;
  owner: 'player' | 'enemy' | 'boss' | 'hazard';
  status?: StatusEffectId;
  knockback?: number;
}

export interface ProjectileSpawnSpec {
  origin: THREE.Vector3;
  direction: THREE.Vector3;
  speed: number;
  lifetime: number;
  payload: ProjectilePayload;
  mode?: ProjectileMovementMode;
  radius?: number;
  scale?: number;
  color?: THREE.ColorRepresentation;
  amplitude?: number;
  frequency?: number;
  turnRate?: number;
  homingTarget?: () => THREE.Vector3;
}

export interface ProjectilePatternSpec extends Omit<ProjectileSpawnSpec, 'origin' | 'direction'> {
  pattern: ProjectilePattern;
  count: number;
  spread?: number;
  spacing?: number;
  arc?: number;
}

export interface ProjectileSnapshot {
  id: number;
  position: THREE.Vector3;
  previousPosition: THREE.Vector3;
  radius: number;
  payload: ProjectilePayload;
  age: number;
  lifetime: number;
}

interface ActiveProjectile {
  id: number;
  active: boolean;
  position: THREE.Vector3;
  previousPosition: THREE.Vector3;
  origin: THREE.Vector3;
  direction: THREE.Vector3;
  perpendicular: THREE.Vector3;
  speed: number;
  lifetime: number;
  age: number;
  distance: number;
  payload: ProjectilePayload;
  mode: ProjectileMovementMode;
  radius: number;
  scale: number;
  color: THREE.Color;
  amplitude: number;
  frequency: number;
  turnRate: number;
  phase: number;
  homingTarget?: () => THREE.Vector3;
}

const Z_AXIS = new THREE.Vector3(0, 0, 1);
const TMP_MATRIX = new THREE.Matrix4();
const TMP_QUAT = new THREE.Quaternion();
const TMP_SCALE = new THREE.Vector3();
const TMP_COLOR = new THREE.Color();

function normalizeDirection(direction: THREE.Vector3): THREE.Vector3 {
  if (direction.lengthSq() < 0.0001) return new THREE.Vector3(1, 0, 0);
  return direction.clone().normalize();
}

function perpendicular2D(direction: THREE.Vector3): THREE.Vector3 {
  const perp = new THREE.Vector3(-direction.y, direction.x, 0);
  if (perp.lengthSq() < 0.0001) return new THREE.Vector3(0, 1, 0);
  return perp.normalize();
}

function rotate2D(direction: THREE.Vector3, radians: number): THREE.Vector3 {
  const c = Math.cos(radians);
  const s = Math.sin(radians);
  return new THREE.Vector3(direction.x * c - direction.y * s, direction.x * s + direction.y * c, direction.z).normalize();
}

function offsetOrigin(origin: THREE.Vector3, direction: THREE.Vector3, offset: number): THREE.Vector3 {
  return origin.clone().addScaledVector(perpendicular2D(direction), offset);
}

function buildSpawn(
  spec: ProjectilePatternSpec,
  origin: THREE.Vector3,
  direction: THREE.Vector3,
  angle: number,
  offset: number,
  mode?: ProjectileMovementMode,
): ProjectileSpawnSpec {
  return {
    origin: offsetOrigin(origin, direction, offset),
    direction: rotate2D(direction, angle),
    speed: spec.speed,
    lifetime: spec.lifetime,
    payload: spec.payload,
    mode: mode ?? spec.mode,
    radius: spec.radius,
    scale: spec.scale,
    color: spec.color,
    amplitude: spec.amplitude,
    frequency: spec.frequency,
    turnRate: spec.turnRate,
    homingTarget: spec.homingTarget,
  };
}

export function spawnPattern(
  spec: ProjectilePatternSpec,
  origin: THREE.Vector3,
  aim: THREE.Vector3,
  rng: () => number,
): ProjectileSpawnSpec[] {
  const count = Math.max(1, Math.floor(spec.count));
  const direction = normalizeDirection(aim);
  const spread = spec.spread ?? Math.PI * 0.35;
  const spacing = spec.spacing ?? 0.22;
  const out: ProjectileSpawnSpec[] = [];

  if (spec.pattern === 'radial') {
    for (let i = 0; i < count; i++) out.push(buildSpawn(spec, origin, direction, (i / count) * Math.PI * 2, 0));
  } else if (spec.pattern === 'cone') {
    const denom = Math.max(1, count - 1);
    for (let i = 0; i < count; i++) {
      const a = -spread * 0.5 + (i / denom) * spread;
      out.push(buildSpawn(spec, origin, direction, a, 0));
    }
  } else if (spec.pattern === 'line') {
    const center = (count - 1) * 0.5;
    for (let i = 0; i < count; i++) out.push(buildSpawn(spec, origin, direction, 0, (i - center) * spacing));
  } else if (spec.pattern === 'spiral') {
    const arc = spec.arc ?? Math.PI * 2.4;
    for (let i = 0; i < count; i++) out.push(buildSpawn(spec, origin, direction, (i / count) * arc, 0, 'spiral'));
  } else if (spec.pattern === 'wave') {
    const center = (count - 1) * 0.5;
    for (let i = 0; i < count; i++) out.push(buildSpawn(spec, origin, direction, 0, (i - center) * spacing, 'sine'));
  } else if (spec.pattern === 'arc') {
    const arc = spec.arc ?? Math.PI;
    const denom = Math.max(1, count - 1);
    for (let i = 0; i < count; i++) out.push(buildSpawn(spec, origin, direction, -arc * 0.5 + (i / denom) * arc, 0));
  } else if (spec.pattern === 'cross') {
    const angles = [0, Math.PI * 0.5, Math.PI, Math.PI * 1.5];
    for (let i = 0; i < count; i++) out.push(buildSpawn(spec, origin, direction, angles[i % angles.length]!, 0));
  } else {
    for (let i = 0; i < count; i++) {
      const jitter = (rng() - 0.5) * spread;
      const offset = (rng() - 0.5) * spacing * count * 0.35;
      out.push(buildSpawn(spec, origin, direction, jitter, offset));
    }
  }

  return out;
}

export class ProjectilePool {
  readonly root = new THREE.Group();
  readonly mesh: THREE.InstancedMesh;
  private readonly projectiles: ActiveProjectile[] = [];
  private readonly snapshotsCache: ProjectileSnapshot[] = [];
  private cursor = 0;
  private nextId = 1;

  constructor(capacity = perfBudget.projectileBudget) {
    const geometry = new THREE.OctahedronGeometry(0.16, 0);
    const material = new THREE.MeshToonMaterial({
      color: '#ffffff',
      gradientMap: getSharedRamp(),
      vertexColors: true,
    });
    this.mesh = new THREE.InstancedMesh(geometry, material, capacity);
    this.mesh.name = 'projectile_pool_mesh';
    this.mesh.frustumCulled = false;
    this.root.name = 'projectile_pool';
    this.root.add(this.mesh);

    for (let i = 0; i < capacity; i++) {
      this.projectiles.push(this.createProjectile());
      this.writeInactiveInstance(i);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
  }

  spawn(spec: ProjectileSpawnSpec): number | null {
    const index = this.findSlot();
    if (index < 0) return null;

    const projectile = this.projectiles[index]!;
    projectile.id = this.nextId++;
    projectile.active = true;
    projectile.origin.copy(spec.origin);
    projectile.position.copy(spec.origin);
    projectile.previousPosition.copy(spec.origin);
    projectile.direction.copy(normalizeDirection(spec.direction));
    projectile.perpendicular.copy(perpendicular2D(projectile.direction));
    projectile.speed = spec.speed;
    projectile.lifetime = spec.lifetime;
    projectile.age = 0;
    projectile.distance = 0;
    projectile.payload = spec.payload;
    projectile.mode = spec.mode ?? 'straight';
    projectile.radius = spec.radius ?? 0.18;
    projectile.scale = spec.scale ?? 1;
    projectile.color.set(spec.color ?? '#b9f5ff');
    projectile.amplitude = spec.amplitude ?? 0.35;
    projectile.frequency = spec.frequency ?? 6;
    projectile.turnRate = spec.turnRate ?? 4.5;
    projectile.phase = this.nextId * 1.618;
    projectile.homingTarget = spec.homingTarget;
    this.writeActiveInstance(index, projectile);
    return projectile.id;
  }

  spawnMany(specs: readonly ProjectileSpawnSpec[]): number {
    let spawned = 0;
    for (const spec of specs) {
      if (this.spawn(spec) !== null) spawned++;
    }
    return spawned;
  }

  spawnPattern(
    spec: ProjectilePatternSpec,
    origin: THREE.Vector3,
    aim: THREE.Vector3,
    rng: () => number,
  ): number {
    return this.spawnMany(spawnPattern(spec, origin, aim, rng));
  }

  update(dt: number): void {
    for (let i = 0; i < this.projectiles.length; i++) {
      const projectile = this.projectiles[i]!;
      if (!projectile.active) continue;

      projectile.age += dt;
      projectile.previousPosition.copy(projectile.position);
      if (projectile.age >= projectile.lifetime) {
        projectile.active = false;
        this.writeInactiveInstance(i);
        continue;
      }

      this.integrate(projectile, dt);
      this.writeActiveInstance(i, projectile);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
    if (this.mesh.instanceColor) this.mesh.instanceColor.needsUpdate = true;
  }

  deactivate(id: number): boolean {
    const index = this.projectiles.findIndex((projectile) => projectile.active && projectile.id === id);
    if (index < 0) return false;
    this.projectiles[index]!.active = false;
    this.writeInactiveInstance(index);
    this.mesh.instanceMatrix.needsUpdate = true;
    return true;
  }

  snapshots(): readonly ProjectileSnapshot[] {
    this.snapshotsCache.length = 0;
    for (const projectile of this.projectiles) {
      if (!projectile.active) continue;
      this.snapshotsCache.push({
        id: projectile.id,
        position: projectile.position.clone(),
        previousPosition: projectile.previousPosition.clone(),
        radius: projectile.radius,
        payload: projectile.payload,
        age: projectile.age,
        lifetime: projectile.lifetime,
      });
    }
    return this.snapshotsCache;
  }

  dispose(): void {
    this.mesh.geometry.dispose();
    if (Array.isArray(this.mesh.material)) {
      for (const material of this.mesh.material) material.dispose();
    } else {
      this.mesh.material.dispose();
    }
  }

  private createProjectile(): ActiveProjectile {
    return {
      id: 0,
      active: false,
      position: new THREE.Vector3(),
      previousPosition: new THREE.Vector3(),
      origin: new THREE.Vector3(),
      direction: new THREE.Vector3(1, 0, 0),
      perpendicular: new THREE.Vector3(0, 1, 0),
      speed: 1,
      lifetime: 1,
      age: 0,
      distance: 0,
      payload: { damage: 0, owner: 'enemy' },
      mode: 'straight',
      radius: 0.18,
      scale: 1,
      color: new THREE.Color('#b9f5ff'),
      amplitude: 0.35,
      frequency: 6,
      turnRate: 4.5,
      phase: 0,
    };
  }

  private findSlot(): number {
    for (let attempt = 0; attempt < this.projectiles.length; attempt++) {
      const index = (this.cursor + attempt) % this.projectiles.length;
      if (!this.projectiles[index]!.active) {
        this.cursor = (index + 1) % this.projectiles.length;
        return index;
      }
    }
    return -1;
  }

  private integrate(projectile: ActiveProjectile, dt: number): void {
    if (projectile.mode === 'homing' && projectile.homingTarget) {
      const target = projectile.homingTarget();
      const desired = target.clone().sub(projectile.position);
      if (desired.lengthSq() > 0.0001) {
        projectile.direction.lerp(desired.normalize(), THREE.MathUtils.clamp(projectile.turnRate * dt, 0, 1)).normalize();
        projectile.perpendicular.copy(perpendicular2D(projectile.direction));
      }
      projectile.position.addScaledVector(projectile.direction, projectile.speed * dt);
      projectile.distance += projectile.speed * dt;
    } else if (projectile.mode === 'sine') {
      projectile.distance += projectile.speed * dt;
      projectile.position
        .copy(projectile.origin)
        .addScaledVector(projectile.direction, projectile.distance)
        .addScaledVector(
          projectile.perpendicular,
          Math.sin(projectile.distance * projectile.frequency + projectile.phase) * projectile.amplitude,
        );
    } else if (projectile.mode === 'spiral') {
      projectile.distance += projectile.speed * dt;
      const angle = projectile.distance * projectile.frequency + projectile.phase;
      const radius = projectile.amplitude * (0.35 + projectile.age / Math.max(projectile.lifetime, 0.01));
      projectile.position
        .copy(projectile.origin)
        .addScaledVector(projectile.direction, projectile.distance)
        .addScaledVector(projectile.perpendicular, Math.cos(angle) * radius)
        .addScaledVector(Z_AXIS, Math.sin(angle) * radius * 0.55);
    } else {
      projectile.position.addScaledVector(projectile.direction, projectile.speed * dt);
      projectile.distance += projectile.speed * dt;
    }
  }

  private writeActiveInstance(index: number, projectile: ActiveProjectile): void {
    TMP_QUAT.setFromUnitVectors(new THREE.Vector3(1, 0, 0), projectile.direction);
    TMP_SCALE.setScalar(projectile.scale);
    TMP_MATRIX.compose(projectile.position, TMP_QUAT, TMP_SCALE);
    this.mesh.setMatrixAt(index, TMP_MATRIX);
    TMP_COLOR.copy(projectile.color);
    this.mesh.setColorAt(index, TMP_COLOR);
  }

  private writeInactiveInstance(index: number): void {
    TMP_MATRIX.compose(new THREE.Vector3(0, -9999, 0), new THREE.Quaternion(), new THREE.Vector3(0.0001, 0.0001, 0.0001));
    this.mesh.setMatrixAt(index, TMP_MATRIX);
    this.mesh.setColorAt(index, new THREE.Color('#000000'));
  }
}
