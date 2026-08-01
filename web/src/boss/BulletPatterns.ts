import * as THREE from 'three';
import { createCelMaterial } from '../render/CelMaterial';

export type RngFn = () => number;

export type ProjectileMovementKind = 'straight' | 'homing' | 'sine' | 'spiral';

export type BulletPatternKind =
  | 'line'
  | 'radial'
  | 'cone'
  | 'spiral'
  | 'wave'
  | 'arc'
  | 'cross'
  | 'scatter';

export interface ProjectileTarget {
  readonly position: THREE.Vector3;
}

export interface ProjectileSpawn {
  readonly position: THREE.Vector3;
  readonly direction: THREE.Vector3;
  readonly speed: number;
  readonly radius: number;
  readonly damage: number;
  readonly lifeSec: number;
  readonly color: THREE.ColorRepresentation;
  readonly movement: ProjectileMovementKind;
  readonly homingTarget?: ProjectileTarget;
  readonly turnRate?: number;
  readonly sineAmplitude?: number;
  readonly sineFrequency?: number;
  readonly spiralAngularVelocity?: number;
}

export interface ProjectileHandle {
  readonly id: number;
  readonly object: THREE.Object3D;
  readonly damage: number;
  readonly radius: number;
  readonly active: boolean;
  readonly ageSec: number;
  despawn(): void;
}

export interface MinimalProjectileSystem {
  readonly group: THREE.Group;
  spawnProjectile(spawn: ProjectileSpawn): ProjectileHandle;
  update(deltaSec: number): void;
  clear(): void;
  activeCount(): number;
}

export interface ExternalProjectilePoolSnapshot {
  readonly id: number;
}

export interface ExternalProjectileSpawnSpec {
  readonly origin: THREE.Vector3;
  readonly direction: THREE.Vector3;
  readonly speed: number;
  readonly lifetime: number;
  readonly payload: {
    readonly damage: number;
    readonly owner: 'boss';
  };
  readonly mode?: ProjectileMovementKind;
  readonly radius?: number;
  readonly scale?: number;
  readonly color?: THREE.ColorRepresentation;
  readonly amplitude?: number;
  readonly frequency?: number;
  readonly turnRate?: number;
  readonly homingTarget?: () => THREE.Vector3;
}

export interface ExternalProjectilePool {
  readonly root: THREE.Group;
  spawn(spec: ExternalProjectileSpawnSpec): number | null;
  update(deltaSec: number): void;
  deactivate?(id: number): boolean;
  snapshots?(): readonly ExternalProjectilePoolSnapshot[];
}

export interface BulletPatternOptions {
  readonly kind: BulletPatternKind;
  readonly origin: THREE.Vector3;
  readonly rng: RngFn;
  readonly target?: ProjectileTarget;
  readonly movement?: ProjectileMovementKind;
  readonly count?: number;
  readonly angleRad?: number;
  readonly spreadRad?: number;
  readonly arcRad?: number;
  readonly lineLength?: number;
  readonly spiralTurns?: number;
  readonly speed?: number;
  readonly speedVariance?: number;
  readonly radius?: number;
  readonly damage?: number;
  readonly lifeSec?: number;
  readonly color?: THREE.ColorRepresentation;
  readonly sineAmplitude?: number;
  readonly sineFrequency?: number;
  readonly homingTurnRate?: number;
  readonly spiralAngularVelocity?: number;
}

export interface BulletPatternRecipe {
  readonly scheduleId: string;
  readonly kind: BulletPatternKind;
  readonly movement: ProjectileMovementKind;
  readonly count: number;
  readonly speed: number;
  readonly damage: number;
  readonly radius: number;
  readonly color: THREE.ColorRepresentation;
  readonly lifeSec: number;
  readonly spreadRad?: number;
  readonly arcRad?: number;
  readonly lineLength?: number;
  readonly spiralTurns?: number;
  readonly sineAmplitude?: number;
  readonly sineFrequency?: number;
  readonly homingTurnRate?: number;
  readonly spiralAngularVelocity?: number;
}

const TAU = Math.PI * 2;
const DEFAULT_PROJECTILE_COLOR = '#ffd36e';

function normalizeDirection(direction: THREE.Vector3): THREE.Vector3 {
  if (direction.lengthSq() <= 0.000001) return new THREE.Vector3(1, 0, 0);
  return direction.clone().normalize();
}

function vectorFromAngle(angleRad: number): THREE.Vector3 {
  return new THREE.Vector3(Math.cos(angleRad), Math.sin(angleRad), 0);
}

function perpendicular2D(direction: THREE.Vector3): THREE.Vector3 {
  const normal = normalizeDirection(direction);
  return new THREE.Vector3(-normal.y, normal.x, 0);
}

function angleToTarget(origin: THREE.Vector3, target: ProjectileTarget | undefined, fallbackAngle: number): number {
  if (!target) return fallbackAngle;
  const delta = target.position.clone().sub(origin);
  if (delta.lengthSq() <= 0.000001) return fallbackAngle;
  return Math.atan2(delta.y, delta.x);
}

function centeredStep(index: number, count: number): number {
  if (count <= 1) return 0;
  return index / (count - 1) - 0.5;
}

function variedSpeed(baseSpeed: number, variance: number, rng: RngFn): number {
  if (variance <= 0) return baseSpeed;
  return Math.max(0.1, baseSpeed + (rng() * 2 - 1) * variance);
}

class SimpleProjectile implements ProjectileHandle {
  readonly id: number;
  readonly object: THREE.Mesh;
  damage = 0;
  radius = 0.2;
  active = false;
  ageSec = 0;

  private direction = new THREE.Vector3(1, 0, 0);
  private speed = 1;
  private lifeSec = 1;
  private movement: ProjectileMovementKind = 'straight';
  private homingTarget: ProjectileTarget | null = null;
  private turnRate = 4;
  private sineAmplitude = 0;
  private sineFrequency = 1;
  private spiralAngularVelocity = 0;

  constructor(id: number, object: THREE.Mesh) {
    this.id = id;
    this.object = object;
    this.object.visible = false;
  }

  activate(spawn: ProjectileSpawn): void {
    this.object.visible = true;
    this.object.position.copy(spawn.position);
    this.object.scale.setScalar(spawn.radius);
    this.direction = normalizeDirection(spawn.direction);
    this.speed = spawn.speed;
    this.radius = spawn.radius;
    this.damage = spawn.damage;
    this.lifeSec = spawn.lifeSec;
    this.movement = spawn.movement;
    this.homingTarget = spawn.homingTarget ?? null;
    this.turnRate = spawn.turnRate ?? 4;
    this.sineAmplitude = spawn.sineAmplitude ?? 0;
    this.sineFrequency = spawn.sineFrequency ?? 1;
    this.spiralAngularVelocity = spawn.spiralAngularVelocity ?? 0;
    this.ageSec = 0;
    this.active = true;
  }

  update(deltaSec: number): void {
    if (!this.active) return;

    const previousAge = this.ageSec;
    this.ageSec += deltaSec;
    if (this.ageSec >= this.lifeSec) {
      this.despawn();
      return;
    }

    if (this.movement === 'homing' && this.homingTarget) {
      const desired = this.homingTarget.position.clone().sub(this.object.position);
      if (desired.lengthSq() > 0.000001) {
        this.direction.lerp(desired.normalize(), Math.min(1, this.turnRate * deltaSec)).normalize();
      }
    }

    if (this.movement === 'spiral') {
      this.direction.applyAxisAngle(new THREE.Vector3(0, 0, 1), this.spiralAngularVelocity * deltaSec).normalize();
    }

    this.object.position.addScaledVector(this.direction, this.speed * deltaSec);

    if (this.movement === 'sine' && this.sineAmplitude > 0) {
      const previousWave = Math.sin(previousAge * this.sineFrequency * TAU) * this.sineAmplitude;
      const nextWave = Math.sin(this.ageSec * this.sineFrequency * TAU) * this.sineAmplitude;
      this.object.position.addScaledVector(perpendicular2D(this.direction), nextWave - previousWave);
    }
  }

  despawn(): void {
    this.active = false;
    this.object.visible = false;
    this.ageSec = 0;
  }
}

class ExternalProjectileHandle implements ProjectileHandle {
  readonly id: number;
  readonly object: THREE.Object3D;
  readonly damage: number;
  readonly radius: number;
  active: boolean;
  ageSec = 0;

  private readonly deactivate: ((id: number) => boolean) | null;

  constructor(
    id: number,
    object: THREE.Object3D,
    damage: number,
    radius: number,
    deactivate: ((id: number) => boolean) | null,
  ) {
    this.id = id;
    this.object = object;
    this.damage = damage;
    this.radius = radius;
    this.deactivate = deactivate;
    this.active = id >= 0;
  }

  despawn(): void {
    if (!this.active) return;
    if (this.deactivate) this.deactivate(this.id);
    this.active = false;
  }
}

export class ProjectilePoolAdapter implements MinimalProjectileSystem {
  readonly group: THREE.Group;

  private readonly pool: ExternalProjectilePool;
  private readonly handles: ExternalProjectileHandle[] = [];

  constructor(pool: ExternalProjectilePool) {
    this.pool = pool;
    this.group = pool.root;
  }

  spawnProjectile(spawn: ProjectileSpawn): ProjectileHandle {
    const homingTarget = spawn.homingTarget;
    const homingTargetProvider =
      homingTarget === undefined ? undefined : () => homingTarget.position.clone();
    const id = this.pool.spawn({
      origin: spawn.position.clone(),
      direction: normalizeDirection(spawn.direction),
      speed: spawn.speed,
      lifetime: spawn.lifeSec,
      payload: {
        damage: spawn.damage,
        owner: 'boss',
      },
      mode: spawn.movement,
      radius: spawn.radius,
      scale: Math.max(0.2, spawn.radius / 0.18),
      color: spawn.color,
      amplitude: spawn.sineAmplitude,
      frequency: spawn.sineFrequency,
      turnRate: spawn.turnRate,
      homingTarget: homingTargetProvider,
    });
    const handle = new ExternalProjectileHandle(
      id ?? -1,
      this.group,
      spawn.damage,
      spawn.radius,
      this.pool.deactivate ? (projectileId) => this.pool.deactivate!(projectileId) : null,
    );
    this.handles.push(handle);
    return handle;
  }

  update(deltaSec: number): void {
    this.pool.update(deltaSec);
    for (const handle of this.handles) {
      if (handle.active) handle.ageSec += deltaSec;
    }
  }

  clear(): void {
    for (const handle of this.handles) handle.despawn();
    this.handles.length = 0;
  }

  activeCount(): number {
    if (this.pool.snapshots) return this.pool.snapshots().length;
    return this.handles.reduce((count, handle) => count + (handle.active ? 1 : 0), 0);
  }
}

export class SimpleProjectilePool implements MinimalProjectileSystem {
  readonly group = new THREE.Group();

  private readonly geometry: THREE.SphereGeometry;
  private readonly material: THREE.ShaderMaterial;
  private readonly projectiles: SimpleProjectile[] = [];
  private nextId = 1;

  constructor(maxProjectiles = 512, projectileColor: THREE.ColorRepresentation = DEFAULT_PROJECTILE_COLOR) {
    this.group.name = 'simple_projectile_pool';
    this.geometry = new THREE.SphereGeometry(1, 12, 8);
    this.material = createCelMaterial({
      color: projectileColor,
      rimColor: '#ffffff',
      rimStrength: 0.95,
      ambient: 0.5,
      specularStrength: 0.55,
    });

    for (let i = 0; i < maxProjectiles; i++) {
      const mesh = new THREE.Mesh(this.geometry, this.material);
      mesh.name = `pooled_projectile_${i}`;
      const projectile = new SimpleProjectile(this.nextId, mesh);
      this.nextId += 1;
      this.projectiles.push(projectile);
      this.group.add(mesh);
    }
  }

  spawnProjectile(spawn: ProjectileSpawn): ProjectileHandle {
    const projectile = this.projectiles.find((candidate) => !candidate.active) ?? this.recycleOldestProjectile();
    projectile.activate(spawn);
    return projectile;
  }

  update(deltaSec: number): void {
    for (const projectile of this.projectiles) projectile.update(deltaSec);
  }

  clear(): void {
    for (const projectile of this.projectiles) projectile.despawn();
  }

  activeCount(): number {
    return this.projectiles.reduce((count, projectile) => count + (projectile.active ? 1 : 0), 0);
  }

  dispose(): void {
    this.geometry.dispose();
    this.material.dispose();
  }

  private recycleOldestProjectile(): SimpleProjectile {
    let oldest = this.projectiles[0]!;
    for (const projectile of this.projectiles) {
      if (projectile.ageSec > oldest.ageSec) oldest = projectile;
    }
    oldest.despawn();
    return oldest;
  }
}

function createSpawn(
  options: BulletPatternOptions,
  position: THREE.Vector3,
  direction: THREE.Vector3,
): ProjectileSpawn {
  const speed = variedSpeed(options.speed ?? 8, options.speedVariance ?? 0, options.rng);
  return {
    position,
    direction,
    speed,
    radius: options.radius ?? 0.24,
    damage: options.damage ?? 10,
    lifeSec: options.lifeSec ?? 7,
    color: options.color ?? DEFAULT_PROJECTILE_COLOR,
    movement: options.movement ?? 'straight',
    homingTarget: options.target,
    turnRate: options.homingTurnRate,
    sineAmplitude: options.sineAmplitude,
    sineFrequency: options.sineFrequency,
    spiralAngularVelocity: options.spiralAngularVelocity,
  };
}

export function emitBulletPattern(
  projectiles: MinimalProjectileSystem,
  options: BulletPatternOptions,
): ProjectileHandle[] {
  const count = Math.max(1, Math.floor(options.count ?? 8));
  const baseAngle = angleToTarget(options.origin, options.target, options.angleRad ?? 0);
  const handles: ProjectileHandle[] = [];

  const spawn = (position: THREE.Vector3, direction: THREE.Vector3): void => {
    handles.push(projectiles.spawnProjectile(createSpawn(options, position, direction)));
  };

  switch (options.kind) {
    case 'line': {
      const direction = vectorFromAngle(baseAngle);
      const lateral = perpendicular2D(direction);
      const lineLength = options.lineLength ?? 8;
      for (let i = 0; i < count; i++) {
        const offset = centeredStep(i, count) * lineLength;
        spawn(options.origin.clone().addScaledVector(lateral, offset), direction);
      }
      break;
    }
    case 'radial': {
      const randomOffset = options.rng() * TAU;
      for (let i = 0; i < count; i++) {
        spawn(options.origin.clone(), vectorFromAngle(randomOffset + (i / count) * TAU));
      }
      break;
    }
    case 'cone': {
      const spread = options.spreadRad ?? Math.PI / 3;
      for (let i = 0; i < count; i++) {
        spawn(options.origin.clone(), vectorFromAngle(baseAngle + centeredStep(i, count) * spread));
      }
      break;
    }
    case 'spiral': {
      const turns = options.spiralTurns ?? 1.5;
      const randomOffset = options.rng() * TAU;
      for (let i = 0; i < count; i++) {
        const t = count <= 1 ? 0 : i / (count - 1);
        spawn(options.origin.clone(), vectorFromAngle(baseAngle + randomOffset + t * turns * TAU));
      }
      break;
    }
    case 'wave': {
      const direction = vectorFromAngle(baseAngle);
      const lateral = perpendicular2D(direction);
      const lineLength = options.lineLength ?? 10;
      for (let i = 0; i < count; i++) {
        const offset = centeredStep(i, count) * lineLength;
        const waveDirection = direction.clone().applyAxisAngle(new THREE.Vector3(0, 0, 1), centeredStep(i, count) * 0.25);
        spawn(options.origin.clone().addScaledVector(lateral, offset), waveDirection);
      }
      break;
    }
    case 'arc': {
      const arc = options.arcRad ?? Math.PI;
      for (let i = 0; i < count; i++) {
        spawn(options.origin.clone(), vectorFromAngle(baseAngle + centeredStep(i, count) * arc));
      }
      break;
    }
    case 'cross': {
      const arms = 4;
      const perArm = Math.max(1, Math.ceil(count / arms));
      for (let arm = 0; arm < arms; arm++) {
        const armAngle = baseAngle + (arm / arms) * TAU;
        const armDirection = vectorFromAngle(armAngle);
        for (let i = 0; i < perArm; i++) {
          const offset = i * 0.55;
          spawn(options.origin.clone().addScaledVector(armDirection, offset), armDirection);
        }
      }
      break;
    }
    case 'scatter': {
      const spread = options.spreadRad ?? TAU;
      for (let i = 0; i < count; i++) {
        const angle = baseAngle + (options.rng() - 0.5) * spread;
        const distance = options.rng() * 1.25;
        spawn(options.origin.clone().addScaledVector(vectorFromAngle(angle), distance), vectorFromAngle(angle));
      }
      break;
    }
  }

  return handles;
}

const PATTERN_RECIPES: Record<string, BulletPatternRecipe> = {
  kallos_rime_lanes: recipe('kallos_rime_lanes', 'line', 'straight', 7, 7.5, 9, '#94d8ff', { lineLength: 12 }),
  kallos_glacier_cross: recipe('kallos_glacier_cross', 'cross', 'straight', 12, 6.8, 10, '#d8f4ff'),
  kallos_shatter_arc: recipe('kallos_shatter_arc', 'arc', 'sine', 11, 7.2, 11, '#b8ebff', {
    arcRad: Math.PI * 0.85,
    sineAmplitude: 0.35,
    sineFrequency: 0.75,
  }),
  kallos_floor_freeze: recipe('kallos_floor_freeze', 'wave', 'sine', 13, 6.5, 12, '#a6e7ff', {
    lineLength: 16,
    sineAmplitude: 0.45,
    sineFrequency: 0.65,
  }),
  kallos_whiteout_spiral: recipe('kallos_whiteout_spiral', 'spiral', 'spiral', 22, 7.8, 14, '#ffffff', {
    spiralTurns: 2.2,
    spiralAngularVelocity: 0.9,
  }),
  vesperra_star_cones: recipe('vesperra_star_cones', 'cone', 'homing', 9, 7.3, 12, '#b78cff', {
    spreadRad: Math.PI * 0.55,
    homingTurnRate: 1.4,
  }),
  vesperra_portal_scatter: recipe('vesperra_portal_scatter', 'scatter', 'straight', 16, 8.0, 10, '#4de3ff', {
    spreadRad: TAU,
  }),
  vesperra_hollow_wave: recipe('vesperra_hollow_wave', 'wave', 'sine', 14, 7.2, 13, '#7c5cff', {
    lineLength: 18,
    sineAmplitude: 0.6,
    sineFrequency: 0.5,
  }),
  vesperra_gate_shuffle: recipe('vesperra_gate_shuffle', 'radial', 'homing', 18, 7.4, 13, '#cf9cff', {
    homingTurnRate: 1.1,
  }),
  vesperra_event_horizon: recipe('vesperra_event_horizon', 'spiral', 'spiral', 28, 8.4, 15, '#2ff7ff', {
    spiralTurns: 3,
    spiralAngularVelocity: -1.1,
  }),
  crit0n_laser_cross: recipe('crit0n_laser_cross', 'cross', 'straight', 16, 9.3, 13, '#ffb347'),
  crit0n_sine_voltage: recipe('crit0n_sine_voltage', 'wave', 'sine', 16, 8.8, 13, '#56f0ff', {
    lineLength: 20,
    sineAmplitude: 0.75,
    sineFrequency: 0.85,
  }),
  crit0n_slag_spiral: recipe('crit0n_slag_spiral', 'spiral', 'spiral', 24, 8.2, 15, '#ff6a3d', {
    spiralTurns: 2.5,
    spiralAngularVelocity: 1.35,
  }),
  crit0n_equation_shift: recipe('crit0n_equation_shift', 'line', 'straight', 11, 10.0, 15, '#fff16a', {
    lineLength: 24,
  }),
  crit0n_overclock: recipe('crit0n_overclock', 'scatter', 'homing', 26, 9.0, 16, '#7df9ff', {
    spreadRad: TAU,
    homingTurnRate: 1.25,
  }),
  pale_wager_coin_lines: recipe('pale_wager_coin_lines', 'line', 'straight', 9, 8.5, 14, '#f5ead7', { lineLength: 16 }),
  pale_wager_cone_bluff: recipe('pale_wager_cone_bluff', 'cone', 'straight', 11, 8.6, 15, '#9c86ff', {
    spreadRad: Math.PI * 0.7,
  }),
  pale_wager_arc_call: recipe('pale_wager_arc_call', 'arc', 'sine', 13, 8.2, 15, '#fff0ce', {
    arcRad: Math.PI * 1.15,
    sineAmplitude: 0.4,
    sineFrequency: 0.7,
  }),
  pale_wager_raise: recipe('pale_wager_raise', 'radial', 'straight', 20, 8.9, 16, '#f5ead7'),
  pale_wager_all_in: recipe('pale_wager_all_in', 'spiral', 'spiral', 30, 9.5, 18, '#fff7e8', {
    spiralTurns: 3.25,
    spiralAngularVelocity: 1.25,
  }),
  choir_seven_radials: recipe('choir_seven_radials', 'radial', 'straight', 21, 8.2, 15, '#ff7ac8'),
  choir_broken_wave: recipe('choir_broken_wave', 'wave', 'sine', 18, 8.4, 16, '#fff06a', {
    lineLength: 20,
    sineAmplitude: 0.55,
    sineFrequency: 0.8,
  }),
  choir_harmony_spiral: recipe('choir_harmony_spiral', 'spiral', 'spiral', 28, 8.8, 17, '#ffaadf', {
    spiralTurns: 2.75,
    spiralAngularVelocity: -1,
  }),
  choir_sixth_grave: recipe('choir_sixth_grave', 'cone', 'homing', 18, 8.5, 17, '#ff7ac8', {
    spreadRad: Math.PI,
    homingTurnRate: 1.35,
  }),
  choir_missing_seventh: recipe('choir_missing_seventh', 'radial', 'sine', 35, 9.0, 19, '#fff8a8', {
    sineAmplitude: 0.35,
    sineFrequency: 1,
  }),
  umbra_shadow_cross: recipe('umbra_shadow_cross', 'cross', 'sine', 20, 8.6, 16, '#6f5cff', {
    sineAmplitude: 0.45,
    sineFrequency: 0.9,
  }),
  umbra_bent_scatter: recipe('umbra_bent_scatter', 'scatter', 'straight', 24, 9.0, 17, '#1ee6a8', { spreadRad: TAU }),
  umbra_sine_eclipse: recipe('umbra_sine_eclipse', 'wave', 'sine', 20, 8.7, 17, '#8e7dff', {
    lineLength: 22,
    sineAmplitude: 0.8,
    sineFrequency: 0.55,
  }),
  umbra_loaded_shadow: recipe('umbra_loaded_shadow', 'arc', 'homing', 18, 8.8, 18, '#5547d8', {
    arcRad: Math.PI * 1.35,
    homingTurnRate: 1.45,
  }),
  umbra_die_break: recipe('umbra_die_break', 'spiral', 'spiral', 36, 9.6, 20, '#1ee6a8', {
    spiralTurns: 3.5,
    spiralAngularVelocity: -1.45,
  }),
  aureline_halo_arc: recipe('aureline_halo_arc', 'arc', 'straight', 18, 9.0, 17, '#ffd36e', {
    arcRad: Math.PI * 1.25,
  }),
  aureline_absolution_lines: recipe('aureline_absolution_lines', 'line', 'homing', 13, 9.2, 18, '#ff6f91', {
    lineLength: 22,
    homingTurnRate: 1.2,
  }),
  aureline_weighted_spiral: recipe('aureline_weighted_spiral', 'spiral', 'spiral', 32, 9.5, 19, '#ffdc8a', {
    spiralTurns: 3,
    spiralAngularVelocity: 1.3,
  }),
  aureline_weighted_grace: recipe('aureline_weighted_grace', 'cone', 'sine', 24, 9.1, 19, '#ffe7a8', {
    spreadRad: Math.PI * 1.2,
    sineAmplitude: 0.5,
    sineFrequency: 0.75,
  }),
  aureline_loaded_miracle: recipe('aureline_loaded_miracle', 'radial', 'homing', 40, 9.8, 21, '#fff1bd', {
    homingTurnRate: 1.3,
  }),
  sovereign_twenty_spokes: recipe('sovereign_twenty_spokes', 'radial', 'straight', 40, 9.6, 19, '#f7d76b'),
  sovereign_decree_waves: recipe('sovereign_decree_waves', 'wave', 'sine', 24, 9.4, 20, '#e04bff', {
    lineLength: 26,
    sineAmplitude: 0.85,
    sineFrequency: 0.7,
  }),
  sovereign_final_edict: recipe('sovereign_final_edict', 'spiral', 'spiral', 48, 10.3, 22, '#ffffff', {
    spiralTurns: 4,
    spiralAngularVelocity: 1.55,
  }),
  sovereign_first_edict: recipe('sovereign_first_edict', 'cross', 'homing', 32, 9.8, 21, '#f7d76b', {
    homingTurnRate: 1.45,
  }),
  sovereign_twentieth_edict: recipe('sovereign_twentieth_edict', 'scatter', 'homing', 52, 10.4, 24, '#e04bff', {
    spreadRad: TAU,
    homingTurnRate: 1.6,
  }),
};

function recipe(
  scheduleId: string,
  kind: BulletPatternKind,
  movement: ProjectileMovementKind,
  count: number,
  speed: number,
  damage: number,
  color: THREE.ColorRepresentation,
  overrides: Partial<Omit<BulletPatternRecipe, 'scheduleId' | 'kind' | 'movement' | 'count' | 'speed' | 'damage' | 'color'>> = {},
): BulletPatternRecipe {
  return {
    scheduleId,
    kind,
    movement,
    count,
    speed,
    damage,
    radius: overrides.radius ?? 0.24,
    color,
    lifeSec: overrides.lifeSec ?? 7.5,
    spreadRad: overrides.spreadRad,
    arcRad: overrides.arcRad,
    lineLength: overrides.lineLength,
    spiralTurns: overrides.spiralTurns,
    sineAmplitude: overrides.sineAmplitude,
    sineFrequency: overrides.sineFrequency,
    homingTurnRate: overrides.homingTurnRate,
    spiralAngularVelocity: overrides.spiralAngularVelocity,
  };
}

function scaleRecipeForDifficulty(base: BulletPatternRecipe, difficultyTier: number): BulletPatternRecipe {
  const tier = Math.max(1, difficultyTier);
  return {
    ...base,
    count: Math.round(base.count * (1 + (tier - 1) * 0.05)),
    speed: base.speed * (1 + (tier - 1) * 0.025),
    damage: Math.round(base.damage * (1 + (tier - 1) * 0.08)),
  };
}

export function getPatternRecipe(scheduleId: string, difficultyTier = 1): BulletPatternRecipe {
  const base = PATTERN_RECIPES[scheduleId] ?? PATTERN_RECIPES.pale_wager_coin_lines;
  return scaleRecipeForDifficulty(base, difficultyTier);
}

export function emitPatternRecipe(
  projectiles: MinimalProjectileSystem,
  recipeToEmit: BulletPatternRecipe,
  origin: THREE.Vector3,
  rng: RngFn,
  target?: ProjectileTarget,
  angleRad?: number,
): ProjectileHandle[] {
  return emitBulletPattern(projectiles, {
    kind: recipeToEmit.kind,
    origin,
    rng,
    target,
    movement: recipeToEmit.movement,
    count: recipeToEmit.count,
    angleRad,
    spreadRad: recipeToEmit.spreadRad,
    arcRad: recipeToEmit.arcRad,
    lineLength: recipeToEmit.lineLength,
    spiralTurns: recipeToEmit.spiralTurns,
    speed: recipeToEmit.speed,
    speedVariance: recipeToEmit.speed * 0.08,
    radius: recipeToEmit.radius,
    damage: recipeToEmit.damage,
    lifeSec: recipeToEmit.lifeSec,
    color: recipeToEmit.color,
    sineAmplitude: recipeToEmit.sineAmplitude,
    sineFrequency: recipeToEmit.sineFrequency,
    homingTurnRate: recipeToEmit.homingTurnRate,
    spiralAngularVelocity: recipeToEmit.spiralAngularVelocity,
  });
}
