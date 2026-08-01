import * as THREE from 'three';

export interface VfxSpawnOptions {
  color?: THREE.ColorRepresentation;
  secondaryColor?: THREE.ColorRepresentation;
  scale?: number;
  lifetime?: number;
  rng?: () => number;
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
}

type VfxMaterial = THREE.MeshBasicMaterial | THREE.LineBasicMaterial;

const PUFF_GEO = new THREE.DodecahedronGeometry(0.18, 0);
const RING_GEO = new THREE.TorusGeometry(0.5, 0.035, 4, 28);
const SPHERE_GEO = new THREE.SphereGeometry(0.5, 12, 8);
const BOX_GEO = new THREE.BoxGeometry(1, 1, 1);
const SPIKE_GEO = new THREE.ConeGeometry(0.12, 0.65, 5);
const ORB_GEO = new THREE.OctahedronGeometry(0.45, 1);

function makeMaterial(color: THREE.ColorRepresentation, opacity = 1): THREE.MeshBasicMaterial {
  return new THREE.MeshBasicMaterial({
    color,
    transparent: opacity < 1,
    opacity,
    depthWrite: opacity >= 1,
    side: THREE.DoubleSide,
  });
}

function makeLineMaterial(color: THREE.ColorRepresentation, opacity = 1): THREE.LineBasicMaterial {
  return new THREE.LineBasicMaterial({
    color,
    transparent: opacity < 1,
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
    this.spawnSmokeCluster(position, 5, 0.22, 0.65, options.color ?? '#d8d1c4', options);
  }

  spawnLandSmoke(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    this.spawnSmokeCluster(position, 8, 0.34, 0.8, options.color ?? '#c9c0b2', options);
  }

  spawnDashSmoke(position: THREE.Vector3, direction: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.38, options.scale ?? 1, (options.scale ?? 1) * 1.75, true);
    const rng = options.rng ?? this.rng;
    for (let i = 0; i < 7; i++) {
      const puff = this.addMesh(item, PUFF_GEO, options.color ?? '#d9d2c6', 0.92);
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
      const puff = this.addMesh(item, PUFF_GEO, options.color ?? '#cfc7bb', 0.9);
      puff.position.copy(randomUnit2(rng).multiplyScalar(0.18 + rng() * 0.18));
      puff.scale.setScalar(0.35 + rng() * 0.35);
    }
    item.angularVelocity.z = 5.5;
  }

  spawnPerfectDodgeFlashRing(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.28, options.scale ?? 0.25, options.scale ?? 1.8, true);
    const ring = this.addMesh(item, RING_GEO, options.color ?? '#fff0a8', 1);
    ring.rotation.x = Math.PI * 0.5;
    const slash = this.addMesh(item, arcGeometry(0.42, 0.54, Math.PI * 1.15), options.secondaryColor ?? '#ffffff', 0.85);
    slash.rotation.z = Math.PI * 0.2;
    addDisposableGeometry(slash);
  }

  spawnAttackArc(position: THREE.Vector3, facing: number, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.22, options.scale ?? 1, (options.scale ?? 1) * 1.08, true);
    const arc = this.addMesh(item, arcGeometry(0.72, 1.1, Math.PI * 0.68), options.color ?? '#ffe08a', 0.95);
    arc.rotation.z = facing < 0 ? Math.PI : 0;
    addDisposableGeometry(arc);
  }

  spawnShieldBubble(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.65, options.scale ?? 1, (options.scale ?? 1) * 1.18, true);
    const shell = this.addMesh(item, SPHERE_GEO, options.color ?? '#75d8ff', 0.28);
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
      item.materials.push(vertical.material, horizontal.material);
    }
    item.velocity.y = 0.45;
  }

  spawnCritStars(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.55, options.scale ?? 0.75, (options.scale ?? 0.75) * 1.45, true);
    const rng = options.rng ?? this.rng;
    for (let i = 0; i < 6; i++) {
      const star = this.addMesh(item, starGeometry(0.16 + rng() * 0.08), options.color ?? '#ffe66d', 1);
      star.position.copy(randomUnit2(rng).multiplyScalar(0.2 + rng() * 0.42));
      star.rotation.z = rng() * Math.PI;
      addDisposableGeometry(star);
    }
    item.angularVelocity.z = 3.2;
  }

  spawnFrostSpikes(position: THREE.Vector3, options: VfxSpawnOptions = {}): void {
    const item = this.activate(position, options.lifetime ?? 0.62, options.scale ?? 1, (options.scale ?? 1) * 0.82, true);
    const rng = options.rng ?? this.rng;
    for (let i = 0; i < 7; i++) {
      const spike = this.addMesh(item, SPIKE_GEO, options.color ?? '#aee8ff', 0.95);
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
      item.materials.push(torus.material);
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
    const line = new THREE.Line(geometry, makeLineMaterial(options.color ?? '#77f7ff', 1));
    item.group.add(line);
    item.materials.push(line.material);
    addDisposableGeometry(line);
  }

  spawnOrbGlow(position: THREE.Vector3, options: VfxSpawnOptions = {}): THREE.Group {
    const item = this.activate(position, options.lifetime ?? 1.2, options.scale ?? 1, (options.scale ?? 1) * 1.1, true);
    const orb = this.addMesh(item, ORB_GEO, options.color ?? '#ffe080', 0.75);
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
      const scale = THREE.MathUtils.lerp(item.startScale, item.endScale, t);
      item.group.scale.setScalar(scale);
      if (item.fade) {
        const opacity = t < 0.7 ? 1 : THREE.MathUtils.lerp(1, 0, (t - 0.7) / 0.3);
        for (const material of item.materials) material.opacity = opacity;
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
    };
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
    item.materials.push(mesh.material);
    return mesh;
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
  }
}
