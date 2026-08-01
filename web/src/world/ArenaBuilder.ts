import * as THREE from 'three';
import { attachOutline, createCelMaterial } from '../render/CelMaterial';
import { getPalette } from '../render/Palettes';
import type { AABB, Vec2, WorldId } from '../core/types';
import { MAX_ADJACENT_PLATFORM_STEP } from '../player/JumpMath';

export type ArenaPlatformKind = 'ice' | 'void' | 'forge' | 'dice';

export interface ArenaPlatform {
  id: string;
  kind: ArenaPlatformKind;
  aabb: AABB;
  mesh: THREE.Group;
  topY: number;
}

export interface ArenaPortal {
  id: string;
  type: 'elevator' | 'door' | 'forge_gate' | 'dice_gate';
  position: Vec2;
  mesh: THREE.Group;
  locked: boolean;
  targetWorld?: WorldId;
  targetFloor?: number;
}

export interface ArenaLaneSegment {
  id: string;
  from: Vec2;
  to: Vec2;
  mesh: THREE.Group;
}

export interface Arena {
  world: WorldId;
  floor: number;
  root: THREE.Group;
  platforms: ArenaPlatform[];
  bounds: AABB;
  spawns: {
    player: Vec2;
    enemies: Vec2[];
  };
  enemyAnchors: Vec2[];
  chest: Vec2;
  gate: ArenaPortal;
  chargeStations: Vec2[];
  sockets: Vec2[];
  portals: ArenaPortal[];
  lanes: ArenaLaneSegment[];
}

type Rng = () => number;

const PLATFORM_DEPTH = 2.2;
const MARKER_DEPTH = 0.08;

function toColor(value: THREE.Color): string {
  return `#${value.getHexString()}`;
}

function cloneVec2(point: Vec2): Vec2 {
  return { x: point.x, y: point.y };
}

function createOutlinedBox(
  parent: THREE.Object3D,
  name: string,
  size: THREE.Vector3,
  position: THREE.Vector3,
  material: THREE.Material,
  ink: THREE.ColorRepresentation,
  outlineWidth: number,
): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(size.x, size.y, size.z), material);
  mesh.name = name;
  mesh.position.copy(position);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  attachOutline(parent, mesh, ink, outlineWidth);
  return mesh;
}

function createPlatform(world: WorldId, id: string, aabb: AABB, kind: ArenaPlatformKind): ArenaPlatform {
  const palette = getPalette(world);
  const group = new THREE.Group();
  group.name = id;

  const platformMat = createCelMaterial({
    color: palette.platform,
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.45,
    specularBand: kind === 'ice' ? 0.78 : 0.88,
    specularStrength: kind === 'forge' ? 0.45 : 0.28,
  });
  const edgeMat = createCelMaterial({
    color: palette.platformEdge,
    rimColor: palette.rim,
    fillColor: palette.accent,
    ambient: 0.38,
    specularBand: 0.84,
    specularStrength: 0.35,
  });

  const center = new THREE.Vector3(aabb.x + aabb.w * 0.5, aabb.y + aabb.h * 0.5, 0);
  createOutlinedBox(
    group,
    `${id}_solid`,
    new THREE.Vector3(aabb.w, aabb.h, PLATFORM_DEPTH),
    center,
    platformMat,
    palette.ink,
    0.035,
  );
  createOutlinedBox(
    group,
    `${id}_front_lip`,
    new THREE.Vector3(aabb.w + 0.12, Math.min(0.18, aabb.h * 0.45), PLATFORM_DEPTH + 0.16),
    new THREE.Vector3(center.x, aabb.y + aabb.h - 0.04, 0.04),
    edgeMat,
    palette.ink,
    0.026,
  );

  if (kind === 'ice') {
    addIceCrestFoam(group, aabb, palette.ink, toColor(palette.cloud));
  } else if (kind === 'forge') {
    addForgeRivets(group, aabb, palette.ink, toColor(palette.accent));
  } else if (kind === 'dice') {
    addDicePips(group, aabb, palette.ink, toColor(palette.accent));
  }

  group.userData.aabb = { ...aabb };
  group.userData.kind = kind;
  return {
    id,
    kind,
    aabb: { ...aabb },
    mesh: group,
    topY: aabb.y + aabb.h,
  };
}

function addIceCrestFoam(
  group: THREE.Group,
  aabb: AABB,
  ink: THREE.ColorRepresentation,
  color: THREE.ColorRepresentation,
): void {
  const mat = createCelMaterial({
    color,
    rimColor: '#ffffff',
    fillColor: '#b8d4f0',
    ambient: 0.55,
    specularBand: 0.72,
    specularStrength: 0.25,
  });
  const count = Math.max(4, Math.floor(aabb.w / 0.85));
  for (let i = 0; i < count; i++) {
    const t = count === 1 ? 0.5 : i / (count - 1);
    const radius = 0.12 + (i % 2) * 0.035;
    const crest = new THREE.Mesh(new THREE.SphereGeometry(radius, 8, 5), mat);
    crest.name = `ice_foam_crest_${i}`;
    crest.position.set(aabb.x + 0.28 + t * Math.max(0.1, aabb.w - 0.56), aabb.y + aabb.h + radius * 0.35, 0.96);
    crest.scale.y = 0.52;
    group.add(crest);
    attachOutline(group, crest, ink, 0.01);
  }
}

function addForgeRivets(
  group: THREE.Group,
  aabb: AABB,
  ink: THREE.ColorRepresentation,
  color: THREE.ColorRepresentation,
): void {
  const mat = createCelMaterial({ color, rimColor: '#ffd78a', fillColor: '#2860e0', ambient: 0.34 });
  const count = Math.max(2, Math.floor(aabb.w / 1.8));
  for (let i = 0; i < count; i++) {
    const rivet = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, 0.05, 8), mat);
    rivet.name = `forge_rivet_${i}`;
    rivet.rotation.x = Math.PI * 0.5;
    rivet.position.set(aabb.x + 0.45 + i * ((aabb.w - 0.9) / Math.max(1, count - 1)), aabb.y + aabb.h + 0.02, 1.12);
    group.add(rivet);
    attachOutline(group, rivet, ink, 0.01);
  }
}

function addDicePips(
  group: THREE.Group,
  aabb: AABB,
  ink: THREE.ColorRepresentation,
  color: THREE.ColorRepresentation,
): void {
  const mat = createCelMaterial({ color, rimColor: '#fff6c8', fillColor: '#604830', ambient: 0.5 });
  const offsets = [-0.25, 0, 0.25];
  for (let i = 0; i < offsets.length; i++) {
    const pip = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, MARKER_DEPTH, 12), mat);
    pip.name = `dice_pip_${i}`;
    pip.rotation.x = Math.PI * 0.5;
    pip.position.set(aabb.x + aabb.w * (0.5 + offsets[i]!), aabb.y + aabb.h + 0.035, 1.13);
    group.add(pip);
    attachOutline(group, pip, ink, 0.008);
  }
}

function createMarker(world: WorldId, id: string, position: Vec2, color?: THREE.ColorRepresentation): THREE.Group {
  const palette = getPalette(world);
  const group = new THREE.Group();
  group.name = id;
  const mat = createCelMaterial({
    color: color ?? palette.accent,
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.42,
    specularBand: 0.76,
    specularStrength: 0.45,
  });
  const base = new THREE.Mesh(new THREE.CylinderGeometry(0.28, 0.34, 0.16, 6), mat);
  base.name = `${id}_base`;
  base.position.set(position.x, position.y + 0.08, 0.78);
  group.add(base);
  attachOutline(group, base, palette.ink, 0.016);

  const crest = new THREE.Mesh(new THREE.OctahedronGeometry(0.24), mat);
  crest.name = `${id}_crest`;
  crest.position.set(position.x, position.y + 0.5, 0.78);
  group.add(crest);
  attachOutline(group, crest, palette.ink, 0.018);
  return group;
}

function createPortal(
  world: WorldId,
  id: string,
  type: ArenaPortal['type'],
  position: Vec2,
  locked: boolean,
  targetWorld?: WorldId,
  targetFloor?: number,
): ArenaPortal {
  const palette = getPalette(world);
  const group = new THREE.Group();
  group.name = id;
  const edge = createCelMaterial({
    color: palette.accent,
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.4,
    specularBand: 0.8,
    specularStrength: 0.5,
  });
  const core = createCelMaterial({
    color: palette.platformEdge,
    rimColor: palette.rim,
    fillColor: palette.accent,
    ambient: 0.55,
    specularBand: 0.72,
    specularStrength: 0.32,
  });

  createOutlinedBox(
    group,
    `${id}_left_post`,
    new THREE.Vector3(0.22, 1.7, 0.32),
    new THREE.Vector3(position.x - 0.48, position.y + 0.85, 0.86),
    edge,
    palette.ink,
    0.02,
  );
  createOutlinedBox(
    group,
    `${id}_right_post`,
    new THREE.Vector3(0.22, 1.7, 0.32),
    new THREE.Vector3(position.x + 0.48, position.y + 0.85, 0.86),
    edge,
    palette.ink,
    0.02,
  );
  createOutlinedBox(
    group,
    `${id}_lintel`,
    new THREE.Vector3(1.2, 0.2, 0.34),
    new THREE.Vector3(position.x, position.y + 1.66, 0.86),
    edge,
    palette.ink,
    0.02,
  );
  createOutlinedBox(
    group,
    `${id}_core`,
    new THREE.Vector3(0.72, 1.18, 0.05),
    new THREE.Vector3(position.x, position.y + 0.8, 0.84),
    core,
    palette.ink,
    0.01,
  );
  group.userData.locked = locked;
  group.userData.portalType = type;
  return {
    id,
    type,
    position: cloneVec2(position),
    mesh: group,
    locked,
    targetWorld,
    targetFloor,
  };
}

function createLaneSegment(world: WorldId, id: string, from: Vec2, to: Vec2): ArenaLaneSegment {
  const palette = getPalette(world);
  const group = new THREE.Group();
  group.name = id;
  const mat = createCelMaterial({
    color: palette.platformEdge,
    rimColor: palette.rim,
    fillColor: palette.accent,
    ambient: 0.48,
    specularBand: 0.76,
    specularStrength: 0.4,
  });
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.hypot(dx, dy);
  const segment = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.045, length, 8), mat);
  segment.name = `${id}_tube`;
  segment.position.set((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, -0.88);
  const direction = new THREE.Vector3(dx, dy, 0).normalize();
  segment.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction);
  group.add(segment);
  attachOutline(group, segment, palette.ink, 0.008);
  return { id, from: cloneVec2(from), to: cloneVec2(to), mesh: group };
}

function createDoorSet(world: WorldId, floor: number, platforms: ArenaPlatform[]): ArenaPortal[] {
  const portals: ArenaPortal[] = [];
  for (let i = 1; i < platforms.length; i += 2) {
    const platform = platforms[i]!;
    const x = i % 4 === 1 ? platform.aabb.x + 0.75 : platform.aabb.x + platform.aabb.w - 0.75;
    const position = { x, y: platform.topY };
    portals.push(createPortal(world, `w${world}_f${floor}_door_${i}`, 'door', position, true));
  }
  return portals;
}

function addPlatforms(root: THREE.Group, platforms: ArenaPlatform[]): void {
  for (const platform of platforms) root.add(platform.mesh);
}

/**
 * Builds ordered platform stacks with a hard upward-step cap. Descending and
 * near-level layouts remain untouched; only impossible upward transitions move.
 */
function createStackPlatform(
  world: WorldId,
  id: string,
  platforms: readonly ArenaPlatform[],
  proposed: AABB,
  kind: ArenaPlatformKind,
): ArenaPlatform {
  const previous = platforms[platforms.length - 1];
  const aabb = { ...proposed };
  if (previous) {
    const proposedTop = aabb.y + aabb.h;
    const maxTop = previous.topY + MAX_ADJACENT_PLATFORM_STEP;
    if (proposedTop > maxTop) aabb.y = maxTop - aabb.h;
  }
  return createPlatform(world, id, aabb, kind);
}

/** Returns any ordered upward transitions that violate the shared jump budget. */
export function validateAdjacentPlatformSteps(
  platforms: readonly ArenaPlatform[],
  maxStep = MAX_ADJACENT_PLATFORM_STEP,
): string[] {
  const violations: string[] = [];
  for (let i = 1; i < platforms.length; i++) {
    const previous = platforms[i - 1]!;
    const current = platforms[i]!;
    if (current.topY - previous.topY > maxStep + 0.0001) {
      violations.push(`${previous.id}->${current.id}`);
    }
  }
  return violations;
}

function computeBounds(platforms: readonly ArenaPlatform[]): AABB {
  let minX = Number.POSITIVE_INFINITY;
  let minY = Number.POSITIVE_INFINITY;
  let maxX = Number.NEGATIVE_INFINITY;
  let maxY = Number.NEGATIVE_INFINITY;
  for (const platform of platforms) {
    minX = Math.min(minX, platform.aabb.x);
    minY = Math.min(minY, platform.aabb.y);
    maxX = Math.max(maxX, platform.aabb.x + platform.aabb.w);
    maxY = Math.max(maxY, platform.aabb.y + platform.aabb.h);
  }
  return {
    x: minX - 4,
    y: minY - 2,
    w: maxX - minX + 8,
    h: maxY - minY + 6,
  };
}

function addArenaDecor(root: THREE.Group, world: WorldId, floor: number, platforms: readonly ArenaPlatform[], bounds: AABB): void {
  addParallaxBackdrop(root, world, floor, bounds);
  addLedgeProps(root, world, platforms);
  if (world === 1) addWorldOneIceDecor(root, floor, platforms, bounds);
}

function addParallaxBackdrop(root: THREE.Group, world: WorldId, floor: number, bounds: AABB): void {
  const palette = getPalette(world);
  const baseColor = palette.platform.clone().lerp(new THREE.Color('#05070d'), world === 1 ? 0.42 : 0.62);
  const farColor = palette.platformEdge.clone().lerp(new THREE.Color('#03040a'), world === 1 ? 0.55 : 0.72);
  const ink = toColor(palette.ink.clone().lerp(new THREE.Color('#000000'), 0.35));

  for (let i = 0; i < 4; i++) {
    const depth = -4 - i * 1.25;
    const width = bounds.w * (0.42 + i * 0.08);
    const height = 1.4 + ((i + floor) % 3) * 0.55;
    const x = bounds.x + bounds.w * (0.18 + i * 0.22) + Math.sin((floor + i) * 1.7) * 0.35;
    const y = bounds.y + 1.2 + i * 2.25;
    const mat = createCelMaterial({
      color: toColor(i % 2 === 0 ? baseColor : farColor),
      rimColor: palette.rim,
      fillColor: palette.fillLight,
      ambient: 0.5,
      specularStrength: 0.08,
    });
    createOutlinedBox(
      root,
      `w${world}_backdrop_slab_${i}`,
      new THREE.Vector3(width, height, 0.22),
      new THREE.Vector3(x, y, depth),
      mat,
      ink,
      0.02,
    );
  }
}

function addLedgeProps(root: THREE.Group, world: WorldId, platforms: readonly ArenaPlatform[]): void {
  const palette = getPalette(world);
  const propMat = createCelMaterial({
    color: palette.platformEdge,
    rimColor: palette.rim,
    fillColor: palette.accent,
    ambient: 0.48,
    specularBand: 0.8,
    specularStrength: 0.22,
  });

  for (let i = 0; i < platforms.length; i++) {
    const platform = platforms[i]!;
    if (platform.aabb.w < 2.8 || i % 2 !== 0) continue;
    const side = i % 4 === 0 ? -1 : 1;
    createOutlinedBox(
      root,
      `${platform.id}_ledge_prop_${i}`,
      new THREE.Vector3(0.38 + (i % 3) * 0.12, 0.16, 0.42),
      new THREE.Vector3(
        platform.aabb.x + platform.aabb.w * (side < 0 ? 0.18 : 0.82),
        platform.topY + 0.1,
        1.24,
      ),
      propMat,
      palette.ink,
      0.014,
    );
  }
}

function addWorldOneIceDecor(root: THREE.Group, floor: number, platforms: readonly ArenaPlatform[], bounds: AABB): void {
  const palette = getPalette(1);
  const iceMat = createCelMaterial({
    color: '#dff7ff',
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.56,
    specularBand: 0.7,
    specularStrength: 0.34,
  });
  const shadowMat = createCelMaterial({
    color: '#6c91ac',
    rimColor: '#dff7ff',
    fillColor: palette.fillLight,
    ambient: 0.46,
    specularStrength: 0.12,
  });

  for (let i = 0; i < Math.min(4, platforms.length); i++) {
    const platform = platforms[i]!;
    const pillarHeight = 1.2 + ((floor + i) % 3) * 0.45;
    const pillar = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.28, pillarHeight, 6), iceMat);
    pillar.name = `${platform.id}_ice_pillar_${i}`;
    pillar.position.set(platform.aabb.x + platform.aabb.w * (0.22 + (i % 2) * 0.48), platform.topY + pillarHeight * 0.5, -0.95);
    pillar.rotation.z = (i % 2 === 0 ? -1 : 1) * 0.08;
    root.add(pillar);
    attachOutline(root, pillar, palette.ink, 0.02);
  }

  for (let i = 0; i < 6; i++) {
    const icicle = new THREE.Mesh(new THREE.ConeGeometry(0.14 + (i % 2) * 0.05, 0.9 + (i % 3) * 0.28, 5), iceMat);
    icicle.name = `w1_hanging_icicle_${i}`;
    icicle.rotation.z = Math.PI;
    icicle.position.set(bounds.x + 1.4 + i * (bounds.w - 2.8) / 5, bounds.y + bounds.h - 0.7 - (i % 2) * 0.3, -1.4);
    root.add(icicle);
    attachOutline(root, icicle, palette.ink, 0.016);
  }

  for (let i = 0; i < 3; i++) {
    const cliff = new THREE.Mesh(new THREE.BoxGeometry(bounds.w * (0.24 + i * 0.05), 2.6 + i * 0.7, 0.18), shadowMat);
    cliff.name = `w1_silhouette_cliff_${i}`;
    cliff.position.set(bounds.x + bounds.w * (0.18 + i * 0.28), bounds.y + 1.4 + i * 3.1, -6.8 - i * 0.55);
    cliff.rotation.z = (i - 1) * 0.08;
    root.add(cliff);
    attachOutline(root, cliff, palette.ink, 0.018);
  }
}

function addArenaMarkers(arena: Arena): void {
  arena.root.add(createMarker(arena.world, `w${arena.world}_f${arena.floor}_chest`, arena.chest));
  arena.root.add(arena.gate.mesh);
  for (let i = 0; i < arena.chargeStations.length; i++) {
    arena.root.add(createMarker(arena.world, `charge_station_${i}`, arena.chargeStations[i]!, '#70e0ff'));
  }
  for (let i = 0; i < arena.sockets.length; i++) {
    arena.root.add(createMarker(arena.world, `socket_${i}`, arena.sockets[i]!, '#ffe080'));
  }
  for (const portal of arena.portals) arena.root.add(portal.mesh);
  for (const lane of arena.lanes) arena.root.add(lane.mesh);
}

function makeArena(
  world: WorldId,
  floor: number,
  platforms: ArenaPlatform[],
  player: Vec2,
  enemies: Vec2[],
  chest: Vec2,
  gate: ArenaPortal,
  chargeStations: Vec2[],
  sockets: Vec2[],
  portals: ArenaPortal[] = [],
  lanes: ArenaLaneSegment[] = [],
): Arena {
  const invalidSteps = validateAdjacentPlatformSteps(platforms);
  if (invalidSteps.length > 0) {
    throw new Error(`Arena has unclearable platform steps: ${invalidSteps.join(', ')}`);
  }
  const root = new THREE.Group();
  root.name = `arena_world_${world}_floor_${floor}`;
  addPlatforms(root, platforms);
  const arena: Arena = {
    world,
    floor,
    root,
    platforms,
    bounds: computeBounds(platforms),
    spawns: { player: cloneVec2(player), enemies: enemies.map(cloneVec2) },
    enemyAnchors: enemies.map(cloneVec2),
    chest: cloneVec2(chest),
    gate,
    chargeStations: chargeStations.map(cloneVec2),
    sockets: sockets.map(cloneVec2),
    portals,
    lanes,
  };
  addArenaDecor(root, world, floor, platforms, arena.bounds);
  addArenaMarkers(arena);
  return arena;
}

function buildWorldOne(floor: number, rng: Rng): Arena {
  const platforms: ArenaPlatform[] = [];
  const tierCount = floor >= 5 ? 7 : 5 + Math.floor(floor * 0.4);
  platforms.push(createPlatform(1, 'w1_base_shelf', { x: -5.6, y: 0, w: 11.2, h: 0.6 }, 'ice'));
  for (let i = 1; i < tierCount; i++) {
    const side = i % 2 === 0 ? -1 : 1;
    const width = 4.1 + rng() * 1.5 - Math.min(1.1, floor * 0.12);
    // 1.93–2.23 unit rises are readable by eye and retain input/timing margin.
    const rise = 2.08 + (rng() - 0.5) * 0.3;
    const y = platforms[i - 1]!.topY + rise - 0.45;
    const x = side * (1.15 + rng() * 1.1) - width * 0.5;
    platforms.push(createStackPlatform(1, `w1_ice_tier_${i}`, platforms, { x, y, w: width, h: 0.45 }, 'ice'));
  }
  const top = platforms[platforms.length - 1]!;
  const enemyAnchors = platforms.slice(1).map((p, i) => ({ x: p.aabb.x + p.aabb.w * (0.35 + (i % 2) * 0.25), y: p.topY }));
  const player = { x: -4.45, y: platforms[0]!.topY };
  const chest = { x: top.aabb.x + top.aabb.w * 0.48, y: top.topY };
  const gate = createPortal(1, `w1_f${floor}_elevator`, 'elevator', { x: top.aabb.x + top.aabb.w - 0.7, y: top.topY }, true, 1, floor + 1);
  return makeArena(1, floor, platforms, player, enemyAnchors, chest, gate, [], []);
}

function buildWorldTwo(floor: number, rng: Rng): Arena {
  const platforms: ArenaPlatform[] = [];
  platforms.push(createPlatform(2, 'w2_arrival_balcony', { x: -4.8, y: 0, w: 4.55 + rng() * 0.35, h: 0.55 }, 'void'));
  platforms.push(createStackPlatform(2, 'w2_right_door_walk', platforms, { x: 1.1, y: 1.75, w: 4.05 + rng() * 0.4, h: 0.5 }, 'void'));
  platforms.push(createStackPlatform(2, 'w2_left_door_walk', platforms, { x: -5.2, y: 3.65, w: 4.4 + rng() * 0.45, h: 0.5 }, 'void'));
  platforms.push(createStackPlatform(2, 'w2_orb_lane_mid', platforms, { x: -1.75 + (rng() - 0.5) * 0.35, y: 5.55, w: 4.2 + rng() * 0.45, h: 0.48 }, 'void'));
  platforms.push(createStackPlatform(2, 'w2_socket_gallery', platforms, { x: 1.1, y: 7.6, w: 4.7 + rng() * 0.45, h: 0.52 }, 'void'));
  if (floor >= 4) platforms.push(createStackPlatform(2, 'w2_boss_antechamber', platforms, { x: -5.6, y: 9.5, w: 5.0 + rng() * 0.45, h: 0.5 }, 'void'));

  const chargeStations = [{ x: platforms[1]!.aabb.x + 0.75, y: platforms[1]!.topY }];
  const sockets = [{ x: platforms[4]!.aabb.x + platforms[4]!.aabb.w - 0.7, y: platforms[4]!.topY }];
  const lanes = [
    createLaneSegment(2, `w2_f${floor}_orb_lane_0`, chargeStations[0]!, { x: -0.2, y: platforms[3]!.topY + 0.45 }),
    createLaneSegment(2, `w2_f${floor}_orb_lane_1`, { x: -0.2, y: platforms[3]!.topY + 0.45 }, sockets[0]!),
  ];
  const portals = createDoorSet(2, floor, platforms);
  const enemyAnchors = platforms.slice(1).map((p, i) => ({ x: p.aabb.x + p.aabb.w * (i % 2 === 0 ? 0.65 : 0.35), y: p.topY }));
  const player = { x: platforms[0]!.aabb.x + 0.7, y: platforms[0]!.topY };
  const top = platforms[platforms.length - 1]!;
  const chest = { x: top.aabb.x + top.aabb.w * 0.42, y: top.topY };
  const gate = createPortal(2, `w2_f${floor}_door_gate`, 'door', { x: top.aabb.x + top.aabb.w - 0.75, y: top.topY }, true, 2, floor + 1);
  return makeArena(2, floor, platforms, player, enemyAnchors, chest, gate, chargeStations, sockets, portals, lanes);
}

function buildWorldThree(floor: number, rng: Rng): Arena {
  const platforms: ArenaPlatform[] = [];
  const count = floor >= 5 ? 8 : 6;
  for (let i = 0; i < count; i++) {
    const width = i === 0 ? 5.6 : 3.4 + rng() * 1.2;
    const x = -5.8 + i * 3.8;
    const y = i === 0 ? 0 : 0.65 + Math.sin(i * 1.4 + floor) * 0.7 + Math.floor(i / 3) * 0.9;
    platforms.push(createStackPlatform(3, `w3_forge_span_${i}`, platforms, { x, y, w: width, h: 0.55 }, 'forge'));
  }
  const enemyAnchors = platforms.slice(1).map((p, i) => ({ x: p.aabb.x + p.aabb.w * (0.45 + (i % 2) * 0.2), y: p.topY }));
  const player = { x: platforms[0]!.aabb.x + 0.8, y: platforms[0]!.topY };
  const end = platforms[platforms.length - 1]!;
  const chest = { x: end.aabb.x + end.aabb.w * 0.35, y: end.topY };
  const gate = createPortal(3, `w3_f${floor}_forge_gate`, 'forge_gate', { x: end.aabb.x + end.aabb.w - 0.7, y: end.topY }, true, 3, floor + 1);
  const sockets = [{ x: end.aabb.x + end.aabb.w * 0.72, y: end.topY }];
  return makeArena(3, floor, platforms, player, enemyAnchors, chest, gate, [], sockets);
}

function buildWorldFour(floor: number, rng: Rng): Arena {
  const platforms: ArenaPlatform[] = [];
  const count = 7 + Math.min(2, floor);
  platforms.push(createPlatform(4, 'w4_origin_die', { x: -3.8, y: 0, w: 7.6, h: 0.58 }, 'dice'));
  for (let i = 1; i < count; i++) {
    const angle = (i / count) * Math.PI * 2 + floor * 0.35;
    const radius = 3.1 + (i % 3) * 0.65;
    const x = Math.cos(angle) * radius - 1.55;
    const y = 1.7 + i * 1.28 + Math.sin(angle) * 0.45 + rng() * 0.2;
    const width = 2.65 + (i % 2) * 0.85;
    const platform = createStackPlatform(4, `w4_dice_shard_${i}`, platforms, { x, y, w: width, h: 0.42 }, 'dice');
    platform.mesh.rotation.z = (rng() - 0.5) * 0.035;
    platforms.push(platform);
  }
  const enemyAnchors = platforms.slice(1).map((p, i) => ({ x: p.aabb.x + p.aabb.w * (i % 3 === 0 ? 0.5 : 0.32), y: p.topY }));
  const player = { x: 0, y: platforms[0]!.topY };
  const top = platforms[platforms.length - 1]!;
  const chest = { x: top.aabb.x + top.aabb.w * 0.5, y: top.topY };
  const gate = createPortal(4, `w4_f${floor}_dice_gate`, 'dice_gate', { x: top.aabb.x + top.aabb.w * 0.74, y: top.topY }, true);
  const chargeStations = [{ x: platforms[2]!.aabb.x + platforms[2]!.aabb.w * 0.5, y: platforms[2]!.topY }];
  const sockets = [{ x: top.aabb.x + top.aabb.w * 0.28, y: top.topY }];
  const lanes = [createLaneSegment(4, `w4_f${floor}_fate_lane`, chargeStations[0]!, sockets[0]!)];
  return makeArena(4, floor, platforms, player, enemyAnchors, chest, gate, chargeStations, sockets, [], lanes);
}

export function buildArena(world: WorldId, floor: number, rng: Rng): Arena {
  if (world === 1) return buildWorldOne(floor, rng);
  if (world === 2) return buildWorldTwo(floor, rng);
  if (world === 3) return buildWorldThree(floor, rng);
  return buildWorldFour(floor, rng);
}
