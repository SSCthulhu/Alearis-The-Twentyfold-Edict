import * as THREE from 'three';

export interface VfxSpawnOptions {
  color?: THREE.ColorRepresentation;
  secondaryColor?: THREE.ColorRepresentation;
  scale?: number;
  lifetime?: number;
  rng?: () => number;
}

export interface TelegraphOptions {
  /** Seconds the telegraph stays visible. Clamped to >= 0.5s. */
  duration?: number;
  radius?: number;
  color?: THREE.ColorRepresentation;
  shape?: 'ring' | 'lane';
  /** Lane direction in the XY plane. Defaults to +X. */
  direction?: THREE.Vector3;
  length?: number;
}

interface VfxItem {
  group: THREE.Group;
  velocity: THREE.Vector3;
  angularVelocity: THREE.Vector3;
  age: number;
  lifetime: number;
  startScale: number;
  endScale: number;
  active: boolean;
  fade: boolean;
  materials: VfxMaterial[];
  /** Authored opacity per material; the fade multiplies this instead of replacing it. */
  baseOpacities: number[];
}

type VfxMaterial = THREE.MeshBasicMaterial | THREE.LineBasicMaterial;

/**
 * Effects hold at full strength then collapse inside this window. A cel effect
 * that dissolves slowly reads as a particle system; the art bible wants a
 * shape that exists and then stops existing.
 */
const FADE_TAIL_SEC = 0.11;

/** World-locked effect colours, refreshed whenever the arena palette changes. */
interface VfxPalette {
  accent: string;
  secondary: string;
  ink: string;
  smoke: string;
}

let PALETTE: VfxPalette = {
  accent: '#ffc94a',
  secondary: '#8ee6ff',
  ink: '#16283c',
  smoke: '#eaf4fb',
};

/**
 * Locks impact/dust colours to the active world so effects sit inside the
 * palette instead of dragging neutral grey-beige across every arena.
 */
export function setVfxPalette(palette: Partial<VfxPalette>): void {
  PALETTE = { ...PALETTE, ...palette };
}

const PUFF_GEO = new THREE.DodecahedronGeometry(0.18, 0);
const RING_GEO = new THREE.TorusGeometry(0.5, 0.035, 4, 28);
const SPHERE_GEO = new THREE.SphereGeometry(0.5, 12, 8);
const BOX_GEO = new THREE.BoxGeometry(1, 1, 1);
const SPIKE_GEO = new THREE.ConeGeometry(0.12, 0.65, 5);
const ORB_GEO = new THREE.OctahedronGeometry(0.45, 1);

// Always transparent: effects fade out on despawn, so an opaque material would
// simply pop instead of collapsing.
function makeMaterial(color: THREE.ColorRepresentation, opacity = 1): THREE.MeshBasicMaterial {
  return new THREE.MeshBasicMaterial({
    color,
    transparent: true,
    opacity,
    depthWrite: opacity >= 1,
    side: THREE.DoubleSide,
  });
}

function makeLineMaterial(color: THREE.ColorRepresentation, opacity = 1): THREE.LineBasicMaterial {
  return new THREE.LineBasicMaterial({
    color,
    transparent: true,
    opacity,
    depthWrite: false,
  });
}

function randomUnit2(rng: () => number): THREE.Vector3 {
  const a = rng() * Math.PI * 2;
  return new THREE.Vector3(Math.cos(a), Math.sin(a), 0);
}

function arcGeometry(innerRadius: number, outerRadius: number, angle: number): THREE.ShapeGeometry {
  const half = angle * 0.5;
  const steps = 16;
  const shape = new THREE.Shape();
  for (let i = 0; i <= steps; i++) {
    const t = -half + (i / steps) * angle;
    const x = Math.cos(t) * outerRadius;
    const y = Math.sin(t) * outerRadius;
    if (i === 0) shape.moveTo(x, y);
    else shape.lineTo(x, y);
  }
  for (let i = steps; i >= 0; i--) {
    const t = -half + (i / steps) * angle;
    shape.lineTo(Math.cos(t) * innerRadius, Math.sin(t) * innerRadius);
  }
  shape.closePath();
  return new THREE.ShapeGeometry(shape);
}

function starGeometry(radius: number): THREE.ShapeGeometry {
  const shape = new THREE.Shape();
  const points = 10;
  for (let i = 0; i <= points; i++) {
    const a = -Math.PI * 0.5 + (i / points) * Math.PI * 2;
    const r = i % 2 === 0 ? radius : radius * 0.42;
    const x = Math.cos(a) * r;
    const y = Math.sin(a) * r;
    if (i === 0) shape.moveTo(x, y);
    else shape.lineTo(x, y);
  }
  shape.closePath();
  return new THREE.ShapeGeometry(shape);
}

/**
 * Arrowhead pointing down +x. Rings say "something happened here"; a chevron
 * says which way the force went, which is the whole reason a hit needs its own
 * shape language rather than another expanding circle.
 */
function chevronGeometry(length: number, halfWidth: number, notch: number): THREE.ShapeGeometry {
  const shape = new THREE.Shape();
  shape.moveTo(length, 0);
  shape.lineTo(0, halfWidth);
  shape.lineTo(notch, 0);
  shape.lineTo(0, -halfWidth);
  shape.closePath();
  return new THREE.ShapeGeometry(shape);
}

function addDisposableGeometry(object: THREE.Object3D): void {
  object.userData.disposeGeometry = true;
}

export class VfxSystem {
  readonly root = new THREE.Group();
  private readonly pool: VfxItem[] = [];
  private cursor = 0;
  private readonly rng: () => number;

  constructor(capacity = 128, rng: () => number = Math.random) {
    this.root.name = 'vfx_system';
    this.rng = rng;
    for (let i = 0; i < capacity; i++) this.pool.push(this.createItem());
  }

  spawnJumpSmoke(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    this.spawnSmokeCluster(position, 5, 0.22, 0.65, options.color ?? PALETTE.smoke, options);
  }

  spawnLandSmoke(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    this.spawnSmokeCluster(position, 8, 0.34, 0.8, options.color ?? PALETTE.smoke, options);
  }

  spawnDashSmoke(position: THREE.Vector3, direction: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.38, options.scale ?? 1, (options.scale ?? 1) * 1.75, true);
    const rng = options.rng ?? this.rng;
    for (let i = 0; i < 7; i++) {
      const puff = this.addMesh(item, PUFF_GEO, options.color ?? PALETTE.smoke, 0.92);
      const back = direction.clone().normalize().multiplyScalar(-0.18 * i);
      const scatter = randomUnit2(rng).multiplyScalar(0.08 + rng() * 0.12);
      puff.position.copy(back.add(scatter));
      puff.scale.setScalar(0.45 + rng() * 0.35);
    }
    item.velocity.copy(direction).multiplyScalar(-0.55);
  }

  spawnRollSmoke(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.48, options.scale ?? 0.8, (options.scale ?? 0.8) * 1.5, true);
    const rng = options.rng ?? this.rng;
    for (let i = 0; i < 6; i++) {
      const puff = this.addMesh(item, PUFF_GEO, options.color ?? PALETTE.smoke, 0.9);
      puff.position.copy(randomUnit2(rng).multiplyScalar(0.18 + rng() * 0.18));
      puff.scale.setScalar(0.35 + rng() * 0.35);
    }
    item.angularVelocity.z = 5.5;
  }

  spawnPerfectDodgeFlashRing(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.28, options.scale ?? 0.25, options.scale ?? 1.8, true);
    const ring = this.addMesh(item, RING_GEO, options.color ?? PALETTE.accent, 1);
    ring.rotation.x = Math.PI * 0.5;
    const slash = this.addInkedShape(item, arcGeometry(0.42, 0.54, Math.PI * 1.15), options.secondaryColor ?? '#ffffff', 0.95, 1.1);
    slash.rotation.z = Math.PI * 0.2;
  }

  spawnAttackArc(position: THREE.Vector3, facing: number, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.22, options.scale ?? 1, (options.scale ?? 1) * 1.08, true);
    const arc = this.addInkedShape(item, arcGeometry(0.72, 1.1, Math.PI * 0.68), options.color ?? PALETTE.accent, 1, 1.07);
    arc.rotation.z = facing < 0 ? Math.PI : 0;
    // Shards thrown along the swing. The arc alone reads as a sweep; the
    // chevrons are what make it read as the swing landing on something.
    const aim = facing < 0 ? Math.PI : 0;
    this.addShardFan(item, aim, 0.62, 3, 0.86, options.secondaryColor ?? '#ffffff');
  }

  /**
   * Directional impact burst — a fan of shard chevrons thrown along `angle`.
   * Use for hits that need a readable direction; rings are for effects that
   * genuinely radiate from a point.
   */
  spawnImpactShards(position: THREE.Vector3, angle: number, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.26, options.scale ?? 1, (options.scale ?? 1) * 1.5, true);
    this.addShardFan(item, angle, 0.9, 5, 1, options.color ?? PALETTE.accent);
  }

  spawnShieldBubble(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.65, options.scale ?? 1, (options.scale ?? 1) * 1.18, true);
    const shell = this.addMesh(item, SPHERE_GEO, options.color ?? PALETTE.secondary, 0.28);
    shell.scale.set(1.1, 1.35, 0.45);
    const ring = this.addMesh(item, RING_GEO, options.secondaryColor ?? '#e8fbff', 0.95);
    ring.rotation.x = Math.PI * 0.5;
    item.angularVelocity.y = 1.4;
  }

  spawnHealCrosses(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.75, options.scale ?? 1, (options.scale ?? 1) * 1.35, true);
    const rng = options.rng ?? this.rng;
    for (let i = 0; i < 5; i++) {
      const cross = new THREE.Group();
      const vertical = this.makeCrossBar(options.color ?? '#75ff9d', 0.12, 0.42);
      const horizontal = this.makeCrossBar(options.color ?? '#75ff9d', 0.36, 0.12);
      cross.add(vertical, horizontal);
      cross.position.copy(randomUnit2(rng).multiplyScalar(0.28 + rng() * 0.34));
      cross.position.y += 0.35 + i * 0.08;
      cross.rotation.z = rng() * Math.PI;
      item.group.add(cross);
      this.track(item, vertical.material);
      this.track(item, horizontal.material);
    }
    item.velocity.y = 0.45;
  }

  spawnCritStars(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.55, options.scale ?? 0.75, (options.scale ?? 0.75) * 1.45, true);
    const rng = options.rng ?? this.rng;
    for (let i = 0; i < 6; i++) {
      const star = this.addInkedShape(item, starGeometry(0.16 + rng() * 0.08), options.color ?? PALETTE.accent, 1, 1.22);
      star.position.copy(randomUnit2(rng).multiplyScalar(0.2 + rng() * 0.42));
      star.rotation.z = rng() * Math.PI;
    }
    // Crit gets shards on all four quadrants: a crit is not directional, but it
    // still needs harder shapes than stars alone to land as a spike in weight.
    for (let i = 0; i < 4; i++) {
      this.addShardFan(item, i * Math.PI * 0.5 + Math.PI * 0.25, 0.34, 1, 0.7, options.secondaryColor ?? '#ffffff');
    }
    item.angularVelocity.z = 3.2;
  }

  spawnFrostSpikes(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.62, options.scale ?? 1, (options.scale ?? 1) * 0.82, true);
    const rng = options.rng ?? this.rng;
    for (let i = 0; i < 7; i++) {
      const spike = this.addMesh(item, SPIKE_GEO, options.color ?? PALETTE.secondary, 0.95);
      spike.position.x = (i - 3) * 0.16;
      spike.position.y = 0.08 * rng();
      spike.rotation.z = (i - 3) * 0.12;
      spike.scale.setScalar(0.8 + rng() * 0.55);
    }
  }

  spawnPortalSwirl(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.9, options.scale ?? 1, (options.scale ?? 1) * 1.25, true);
    for (let i = 0; i < 4; i++) {
      const torus = new THREE.Mesh(
        new THREE.TorusGeometry(0.32 + i * 0.13, 0.022, 4, 24, Math.PI * 1.25),
        makeMaterial(i % 2 === 0 ? options.color ?? '#e040a0' : options.secondaryColor ?? '#3ef0d0', 0.9),
      );
      torus.rotation.z = i * Math.PI * 0.42;
      item.group.add(torus);
      this.track(item, torus.material);
      addDisposableGeometry(torus);
    }
    item.angularVelocity.z = 4.4;
  }

  spawnElectricArc(start: THREE.Vector3, end: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const midpoint = start.clone().lerp(end, 0.5);
    const item = this.activate(midpoint, options.lifetime ?? 0.18, options.scale ?? 1, options.scale ?? 1, true);
    const rng = options.rng ?? this.rng;
    const localStart = start.clone().sub(midpoint);
    const localEnd = end.clone().sub(midpoint);
    const points: THREE.Vector3[] = [];
    for (let i = 0; i <= 7; i++) {
      const t = i / 7;
      const point = localStart.clone().lerp(localEnd, t);
      point.add(randomUnit2(rng).multiplyScalar(i === 0 || i === 7 ? 0 : 0.08 + rng() * 0.08));
      points.push(point);
    }
    const geometry = new THREE.BufferGeometry().setFromPoints(points);
    const line = new THREE.Line(geometry, makeLineMaterial(options.color ?? PALETTE.secondary, 1));
    item.group.add(line);
    this.track(item, line.material);
    addDisposableGeometry(line);
  }

  /**
   * Flat, hard-edged cel telegraph shown before boss patterns fire.
   * Ring for radial bursts, lane for horizontal sweeps. No soft gradients —
   * opacity holds until the final 30% then snaps out via the standard fade.
   */
  spawnGroundTelegraph(position: THREE.Vector3, options: TelegraphOptions = {}): void {
    const duration = Math.max(0.5, options.duration ?? 0.7);
    const color = options.color ?? '#ff5a5a';

    if ((options.shape ?? 'ring') === 'lane') {
      const direction = (options.direction ?? new THREE.Vector3(1, 0, 0)).clone();
      direction.z = 0;
      if (direction.lengthSq() < 0.000001) direction.set(1, 0, 0);
      direction.normalize();
      const length = options.length ?? 9;
      const angle = Math.atan2(direction.y, direction.x);
      const item = this.activate(position, duration, 1, 1, true);

      const fill = this.addMesh(item, BOX_GEO, color, 0.3);
      fill.scale.set(length, 0.9, 0.06);
      fill.position.copy(direction.clone().multiplyScalar(length * 0.5));
      fill.rotation.z = angle;

      for (const side of [-1, 1]) {
        const edge = this.addMesh(item, BOX_GEO, color, 0.95);
        edge.scale.set(length, 0.08, 0.07);
        edge.position.copy(direction.clone().multiplyScalar(length * 0.5));
        edge.position.x += -Math.sin(angle) * 0.45 * side;
        edge.position.y += Math.cos(angle) * 0.45 * side;
        edge.rotation.z = angle;
      }
      return;
    }

    const radius = options.radius ?? 2.2;
    const item = this.activate(position, duration, 0.86, 1, true);
    // Ink under-ring first so the danger zone has a hard contour against any
    // platform colour, then the bright rim, then the transparent fill.
    const inkRim = this.addMesh(item, new THREE.RingGeometry(radius * 0.82, radius * 1.04, 40), PALETTE.ink, 0.9);
    inkRim.position.z = -0.012;
    addDisposableGeometry(inkRim);
    const rim = this.addMesh(item, new THREE.RingGeometry(radius * 0.86, radius, 40), color, 0.95);
    addDisposableGeometry(rim);
    const fill = this.addMesh(item, new THREE.CircleGeometry(radius * 0.86, 40), color, 0.2);
    addDisposableGeometry(fill);
    const core = this.addMesh(item, new THREE.RingGeometry(radius * 0.3, radius * 0.38, 32), color, 0.85);
    addDisposableGeometry(core);
  }

  spawnOrbGlow(position: THREE.Vector3, options: VfxSpawnOptions = {}): THREE.Group {
    const item = this.activate(position, options.lifetime ?? 1.2, options.scale ?? 1, (options.scale ?? 1) * 1.1, true);
    const orb = this.addMesh(item, ORB_GEO, options.color ?? PALETTE.accent, 0.75);
    orb.scale.setScalar(0.55);
    for (let i = 0; i < 2; i++) {
      const ring = this.addMesh(item, RING_GEO, options.secondaryColor ?? '#fff4b8', 0.7);
      ring.scale.setScalar(0.75 + i * 0.28);
      ring.rotation.x = Math.PI * (0.35 + i * 0.2);
      ring.rotation.y = Math.PI * (0.15 + i * 0.25);
    }
    item.angularVelocity.y = 2.2;
    return item.group;
  }

  update(dt: number): void {
    for (const item of this.pool) {
      if (!item.active) continue;
      item.age += dt;
      const t = item.age / item.lifetime;
      if (t >= 1) {
        item.active = false;
        item.group.visible = false;
        continue;
      }
      item.group.position.addScaledVector(item.velocity, dt);
      item.group.rotation.x += item.angularVelocity.x * dt;
      item.group.rotation.y += item.angularVelocity.y * dt;
      item.group.rotation.z += item.angularVelocity.z * dt;
      // Snap out to the full pose almost immediately, then hold. A linear grow
      // reads as a soft particle; the front-loaded curve reads as an impact.
      const snap = 1 - Math.pow(1 - t, 3);
      item.group.scale.setScalar(THREE.MathUtils.lerp(item.startScale, item.endScale, snap));
      if (item.fade) {
        const holdUntil = Math.max(0, 1 - FADE_TAIL_SEC / item.lifetime);
        const k = t < holdUntil ? 1 : 1 - (t - holdUntil) / Math.max(0.0001, 1 - holdUntil);
        // Scale each material's authored opacity rather than forcing it to 1,
        // otherwise translucent telegraph fills render as solid slabs.
        for (let i = 0; i < item.materials.length; i++) {
          item.materials[i]!.opacity = (item.baseOpacities[i] ?? 1) * k;
        }
      }
    }
  }

  dispose(): void {
    for (const item of this.pool) this.clearGroup(item);
    PUFF_GEO.dispose();
    RING_GEO.dispose();
    SPHERE_GEO.dispose();
    BOX_GEO.dispose();
    SPIKE_GEO.dispose();
    ORB_GEO.dispose();
  }

  private spawnSmokeCluster(
    position: THREE.Vector3,
    count: number,
    speed: number,
    lifetime: number,
    color: THREE.ColorRepresentation,
    options: VfxSpawnOptions,
  ): void {
    const item = this.activate(position, options.lifetime ?? lifetime, options.scale ?? 0.75, (options.scale ?? 0.75) * 1.8, true);
    const rng = options.rng ?? this.rng;
    for (let i = 0; i < count; i++) {
      const puff = this.addMesh(item, PUFF_GEO, color, 0.9);
      const dir = randomUnit2(rng);
      puff.position.copy(dir.multiplyScalar(0.08 + rng() * 0.18));
      puff.scale.setScalar(0.32 + rng() * 0.42);
    }
    item.velocity.y = speed;
  }

  private activate(position: THREE.Vector3, lifetime: number, startScale: number, endScale: number, fade: boolean): VfxItem {
    const item = this.pool[this.cursor]!;
    this.cursor = (this.cursor + 1) % this.pool.length;
    this.clearGroup(item);
    item.group.position.copy(position);
    item.group.rotation.set(0, 0, 0);
    item.group.scale.setScalar(startScale);
    item.group.visible = true;
    item.velocity.set(0, 0, 0);
    item.angularVelocity.set(0, 0, 0);
    item.age = 0;
    item.lifetime = Math.max(0.01, lifetime);
    item.startScale = startScale;
    item.endScale = endScale;
    item.fade = fade;
    item.active = true;
    return item;
  }

  private createItem(): VfxItem {
    const group = new THREE.Group();
    group.visible = false;
    this.root.add(group);
    return {
      group,
      velocity: new THREE.Vector3(),
      angularVelocity: new THREE.Vector3(),
      age: 0,
      lifetime: 1,
      startScale: 1,
      endScale: 1,
      active: false,
      fade: true,
      materials: [],
      baseOpacities: [],
    };
  }

  private track(item: VfxItem, material: VfxMaterial): void {
    item.materials.push(material);
    item.baseOpacities.push(material.opacity);
  }

  private addMesh(
    item: VfxItem,
    geometry: THREE.BufferGeometry,
    color: THREE.ColorRepresentation,
    opacity: number,
  ): THREE.Mesh<THREE.BufferGeometry, THREE.MeshBasicMaterial> {
    const mesh = new THREE.Mesh(geometry, makeMaterial(color, opacity));
    mesh.renderOrder = 20;
    item.group.add(mesh);
    this.track(item, mesh.material);
    return mesh;
  }

  /**
   * Flat shape backed by a slightly larger ink copy — the 2D equivalent of the
   * inverted-hull outline the meshes use, so effects carry the same contour
   * weight as everything else on screen.
   */
  private addInkedShape(
    item: VfxItem,
    geometry: THREE.BufferGeometry,
    color: THREE.ColorRepresentation,
    opacity: number,
    inkScale: number,
  ): THREE.Group {
    const group = new THREE.Group();
    const ink = new THREE.Mesh(geometry, makeMaterial(PALETTE.ink, opacity));
    ink.scale.setScalar(inkScale);
    ink.position.z = -0.012;
    ink.renderOrder = 19;
    const fill = new THREE.Mesh(geometry, makeMaterial(color, opacity));
    fill.renderOrder = 20;
    group.add(ink, fill);
    item.group.add(group);
    this.track(item, ink.material);
    this.track(item, fill.material);
    // Shared geometry, so only one child owns disposal.
    addDisposableGeometry(fill);
    return group;
  }

  /**
   * Fan of inked chevrons pointing outward from the item origin. Each shard is
   * a different length so the fan has a leading spike rather than a symmetric
   * comb, which is what stops it reading as a decorative starburst.
   */
  private addShardFan(
    item: VfxItem,
    angle: number,
    reach: number,
    count: number,
    scale: number,
    color: THREE.ColorRepresentation,
  ): void {
    const spread = count > 1 ? 0.68 : 0;
    for (let i = 0; i < count; i++) {
      const t = count > 1 ? i / (count - 1) - 0.5 : 0;
      const theta = angle + t * spread;
      // Centre shard runs longest; the flankers fall back off it.
      const lengthK = 1 - Math.abs(t) * 0.9;
      const shard = this.addInkedShape(
        item,
        chevronGeometry(scale * (0.26 + lengthK * 0.3), scale * 0.13, scale * 0.1),
        color,
        1,
        1.3,
      );
      shard.position.set(Math.cos(theta) * reach * (0.62 + lengthK * 0.38), Math.sin(theta) * reach * (0.62 + lengthK * 0.38), 0.01);
      shard.rotation.z = theta;
    }
  }

  private makeCrossBar(
    color: THREE.ColorRepresentation,
    width: number,
    height: number,
  ): THREE.Mesh<THREE.BoxGeometry, THREE.MeshBasicMaterial> {
    const mesh = new THREE.Mesh(BOX_GEO, makeMaterial(color, 1));
    mesh.scale.set(width, height, 0.06);
    return mesh;
  }

  private clearGroup(item: VfxItem): void {
    while (item.group.children.length > 0) {
      const child = item.group.children[0]!;
      item.group.remove(child);
      child.traverse((object) => {
        if (object instanceof THREE.Mesh || object instanceof THREE.Line) {
          if (object.userData.disposeGeometry) object.geometry.dispose();
          const material = object.material;
          if (Array.isArray(material)) {
            for (const entry of material) entry.dispose();
          } else {
            material.dispose();
          }
        }
      });
    }
    item.materials.length = 0;
    item.baseOpacities.length = 0;
  }
}
