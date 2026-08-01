import * as THREE from 'three';
import { KAYKIT_PROPS, applyCelMaterials, cloneCachedGLTF, hasCachedGLTF } from '../assets/KayKitLoader';
import { attachOutline, createCelMaterial, type SurfaceTextureKind } from '../render/CelMaterial';
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
  /** World 2 fate mechanic: id of the portal that instantly charges the orb. Null elsewhere. */
  correctPortalId: string | null;
}

type Rng = () => number;

const PLATFORM_DEPTH = 2.2;
const MARKER_DEPTH = 0.08;

interface ParallaxDrift {
  baseX: number;
  baseY: number;
  ampX: number;
  ampY: number;
  speed: number;
  phase: number;
}

function toColor(value: THREE.Color): string {
  return `#${value.getHexString()}`;
}

/** Deterministic 0..1 jitter from integer seeds — decor never consumes run RNG. */
function decorJitter(a: number, b = 0): number {
  const s = Math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return s - Math.floor(s);
}

function makeParallaxLayer(root: THREE.Group, name: string, z: number, drift: ParallaxDrift): THREE.Group {
  const layer = new THREE.Group();
  layer.name = name;
  layer.position.set(drift.baseX, drift.baseY, z);
  layer.userData.drift = drift;
  root.add(layer);
  const layers = (root.userData.parallaxLayers as THREE.Group[] | undefined) ?? [];
  layers.push(layer);
  root.userData.parallaxLayers = layers;
  return layer;
}

/** Gentle sinusoidal drift for registered parallax layers; call once per frame. */
export function updateArenaDrift(arenaRoot: THREE.Group, time: number): void {
  const layers = arenaRoot.userData.parallaxLayers as THREE.Group[] | undefined;
  if (!layers) return;
  for (const layer of layers) {
    const drift = layer.userData.drift as ParallaxDrift;
    layer.position.x = drift.baseX + Math.sin(time * drift.speed + drift.phase) * drift.ampX;
    layer.position.y = drift.baseY + Math.cos(time * drift.speed * 0.7 + drift.phase) * drift.ampY;
  }
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

/**
 * Normalizes a cached KayKit prop to a feet-origin gameplay marker. Cached
 * geometry, materials and textures stay owned by KayKitLoader across floors.
 */
function createKayKitProp(
  url: string,
  name: string,
  position: Vec2,
  targetHeight: number,
  depth: number,
): THREE.Group | null {
  if (!hasCachedGLTF(url)) return null;

  const model = cloneCachedGLTF(url).scene;
  model.updateMatrixWorld(true);
  const sourceBounds = new THREE.Box3().setFromObject(model);
  const sourceHeight = sourceBounds.max.y - sourceBounds.min.y;
  if (sourceBounds.isEmpty() || !Number.isFinite(sourceHeight) || sourceHeight <= 0.001) return null;

  const sourceCenter = sourceBounds.getCenter(new THREE.Vector3());
  const visualScale = targetHeight / sourceHeight;
  model.scale.setScalar(visualScale);
  model.position.set(
    position.x - sourceCenter.x * visualScale,
    position.y - sourceBounds.min.y * visualScale,
    depth - sourceCenter.z * visualScale,
  );
  // Match the actors: cel-convert the prop's PBR materials so chests, barrels
  // and crates carry the same NPR grade instead of leaning on scene lights.
  applyCelMaterials(model);

  model.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;
    object.castShadow = true;
    object.receiveShadow = true;
    object.frustumCulled = true;
    object.userData.cacheOwnedResources = true;
  });

  const root = new THREE.Group();
  root.name = name;
  root.userData.kayKitProp = true;
  root.add(model);
  return root;
}

/**
 * A platform is three surfaces, never one box: a bright top face the player
 * reads as safe ground, a saturated front lip that carries the shape against
 * the sky, and a dark body that gives the slab real thickness.
 */
interface PlatformSkin {
  body: THREE.Material;
  top: THREE.Material;
  lip: THREE.Material;
  /** Extra tonal step drawn under the lip so the underside never reads as paper. */
  shade: THREE.Material;
}

const SURFACE_BY_KIND: Record<ArenaPlatformKind, SurfaceTextureKind> = {
  ice: 'ice',
  void: 'metal',
  forge: 'metal',
  dice: 'crackle',
};

function createPlatformSkin(world: WorldId, kind: ArenaPlatformKind): PlatformSkin {
  const palette = getPalette(world);
  const surface = SURFACE_BY_KIND[kind];
  const shadowTint = palette.ramp[0];

  const body = createCelMaterial({
    color: palette.platformDeep,
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    shadowTint,
    shadowBias: 0.7,
    texture: surface,
    texScale: 0.42,
    texStrength: 0.34,
    matcapMix: 0.1,
    ambient: 0.3,
    specularBand: 0.93,
    specularStrength: kind === 'forge' ? 0.24 : 0.1,
    rimStrength: kind === 'void' ? 0.75 : 0.3,
  });

  const top = createCelMaterial({
    color: palette.platform,
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    shadowTint,
    shadowBias: 0.5,
    texture: surface,
    texScale: 0.62,
    texStrength: kind === 'ice' ? 0.4 : 0.26,
    matcapMix: kind === 'ice' ? 0.2 : 0.1,
    ambient: kind === 'dice' ? 0.68 : 0.6,
    specularBand: kind === 'ice' ? 0.7 : 0.88,
    specularStrength: kind === 'ice' ? 0.6 : kind === 'forge' ? 0.4 : 0.2,
  });

  // The lip is the shape-reader: most saturated, least broken up, hardest spec.
  const lip = createCelMaterial({
    color: palette.platformEdge,
    rimColor: palette.rim,
    fillColor: palette.accent,
    shadowTint,
    shadowBias: 0.42,
    matcapMix: 0.06,
    ambient: 0.55,
    specularBand: 0.76,
    specularStrength: 0.42,
    rimStrength: 0.6,
  });

  const shade = createCelMaterial({
    color: toColor(palette.platformDeep.clone().lerp(palette.ink, 0.45)),
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    shadowTint,
    shadowBias: 0.8,
    matcapMix: 0,
    ambient: 0.22,
    specularStrength: 0,
    rimStrength: 0.18,
  });

  return { body, top, lip, shade };
}

function createPlatform(world: WorldId, id: string, aabb: AABB, kind: ArenaPlatformKind): ArenaPlatform {
  const palette = getPalette(world);
  const group = new THREE.Group();
  group.name = id;
  const skin = createPlatformSkin(world, kind);

  const centerX = aabb.x + aabb.w * 0.5;
  const topY = aabb.y + aabb.h;

  // 1. Dark body — thickness and ground shadow.
  createOutlinedBox(
    group,
    `${id}_body`,
    new THREE.Vector3(aabb.w, aabb.h, PLATFORM_DEPTH),
    new THREE.Vector3(centerX, aabb.y + aabb.h * 0.5, 0),
    skin.body,
    palette.ink,
    0.035,
  );

  // 2. Bright top face — the "this is safe ground" read.
  const topThickness = Math.min(0.14, aabb.h * 0.42);
  createOutlinedBox(
    group,
    `${id}_top_face`,
    new THREE.Vector3(aabb.w * 0.985, topThickness, PLATFORM_DEPTH * 0.97),
    new THREE.Vector3(centerX, topY - topThickness * 0.35, 0),
    skin.top,
    palette.ink,
    0.022,
  );

  // 3. Saturated front lip — the primary silhouette band against the sky.
  const lipHeight = Math.min(0.2, Math.max(0.11, aabb.h * 0.5));
  createOutlinedBox(
    group,
    `${id}_front_lip`,
    new THREE.Vector3(aabb.w + 0.14, lipHeight, PLATFORM_DEPTH + 0.2),
    new THREE.Vector3(centerX, topY - lipHeight * 0.55, 0.04),
    skin.lip,
    palette.ink,
    0.026,
  );

  // Underside shade band so the slab never flattens into a cutout.
  createOutlinedBox(
    group,
    `${id}_under_shade`,
    new THREE.Vector3(aabb.w + 0.04, Math.min(0.1, aabb.h * 0.3), PLATFORM_DEPTH + 0.1),
    new THREE.Vector3(centerX, aabb.y + 0.03, 0.03),
    skin.shade,
    palette.ink,
    0.014,
  );

  if (kind === 'ice') {
    addIceCrestFoam(group, aabb, palette.ink, '#ffffff');
    addSnowCaps(group, aabb, palette.ink);
    addIcicleFringe(group, aabb, palette.ink);
  } else if (kind === 'void') {
    addVoidSeam(group, aabb);
  } else if (kind === 'forge') {
    addForgeRivets(group, aabb, palette.ink, toColor(palette.accent));
    addMoltenSeam(group, aabb);
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
    topY,
  };
}

/** Snow accumulation drifting along the upper edges — frost, not gray stone. */
function addSnowCaps(group: THREE.Group, aabb: AABB, ink: THREE.ColorRepresentation): void {
  const mat = createCelMaterial({
    color: '#ffffff',
    rimColor: '#fff0bc',
    fillColor: '#8fc4e8',
    shadowTint: '#7fa6c8',
    shadowBias: 0.62,
    matcapMix: 0.04,
    ambient: 0.72,
    specularBand: 0.86,
    specularStrength: 0.18,
  });
  const count = Math.max(2, Math.floor(aabb.w / 1.5));
  for (let i = 0; i < count; i++) {
    const j = decorJitter(i * 3 + 1, Math.round(aabb.x * 10));
    const width = aabb.w / count * (0.5 + j * 0.4);
    const cap = new THREE.Mesh(new THREE.SphereGeometry(width * 0.5, 9, 5), mat);
    cap.name = `snow_cap_${i}`;
    cap.position.set(
      aabb.x + (i + 0.5) * (aabb.w / count) + (j - 0.5) * 0.2,
      aabb.y + aabb.h + 0.02,
      -0.35 + j * 0.3,
    );
    cap.scale.set(1, 0.3 + j * 0.16, 0.7);
    group.add(cap);
    attachOutline(group, cap, ink, 0.012);
  }
}

/** Icicles hanging off the underside — sells the slab's thickness from below. */
function addIcicleFringe(group: THREE.Group, aabb: AABB, ink: THREE.ColorRepresentation): void {
  const mat = createCelMaterial({
    color: '#bfe8fb',
    rimColor: '#ffffff',
    fillColor: '#57b6e4',
    shadowTint: '#4a6f9c',
    shadowBias: 0.6,
    matcapMix: 0.22,
    ambient: 0.5,
    specularBand: 0.7,
    specularStrength: 0.55,
  });
  const count = Math.max(2, Math.floor(aabb.w / 1.3));
  for (let i = 0; i < count; i++) {
    const j = decorJitter(i * 5 + 2, Math.round(aabb.y * 10));
    const len = 0.22 + j * 0.4;
    const icicle = new THREE.Mesh(new THREE.ConeGeometry(0.055 + j * 0.03, len, 5), mat);
    icicle.name = `icicle_fringe_${i}`;
    icicle.rotation.z = Math.PI;
    icicle.position.set(aabb.x + 0.3 + i * ((aabb.w - 0.6) / Math.max(1, count - 1)), aabb.y - len * 0.44, 0.85);
    group.add(icicle);
    attachOutline(group, icicle, ink, 0.01);
  }
}

/** Thin unlit teal seam plus magenta underglow along the void lip. */
function addVoidSeam(group: THREE.Group, aabb: AABB): void {
  const seam = new THREE.Mesh(
    new THREE.BoxGeometry(aabb.w * 0.94, 0.035, 0.06),
    new THREE.MeshBasicMaterial({ color: '#7cf0e6' }),
  );
  seam.name = 'void_seam';
  seam.position.set(aabb.x + aabb.w * 0.5, aabb.y + aabb.h - 0.12, PLATFORM_DEPTH * 0.5 + 0.14);
  group.add(seam);

  const glow = new THREE.Mesh(
    new THREE.PlaneGeometry(aabb.w * 0.98, 0.34),
    new THREE.MeshBasicMaterial({ color: '#e040a0', transparent: true, opacity: 0.3, depthWrite: false }),
  );
  glow.name = 'void_underglow';
  glow.position.set(aabb.x + aabb.w * 0.5, aabb.y - 0.14, PLATFORM_DEPTH * 0.5 + 0.12);
  group.add(glow);
}

/** Molten seam under the tesla-blue lip — the forge's complementary clash. */
function addMoltenSeam(group: THREE.Group, aabb: AABB): void {
  const seam = new THREE.Mesh(
    new THREE.BoxGeometry(aabb.w * 0.9, 0.05, 0.08),
    new THREE.MeshBasicMaterial({ color: '#ff8c3a' }),
  );
  seam.name = 'molten_seam';
  seam.position.set(aabb.x + aabb.w * 0.5, aabb.y + aabb.h - 0.22, PLATFORM_DEPTH * 0.5 + 0.14);
  group.add(seam);
}

function addIceCrestFoam(
  group: THREE.Group,
  aabb: AABB,
  ink: THREE.ColorRepresentation,
  color: THREE.ColorRepresentation,
): void {
  const mat = createCelMaterial({
    color,
    rimColor: '#fff0bc',
    fillColor: '#8fc4e8',
    shadowTint: '#7fa6c8',
    shadowBias: 0.58,
    matcapMix: 0.05,
    ambient: 0.7,
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

/** Cel-styled banner: stone base, dark pole, pennant flag in the point color. */
function createMarker(world: WorldId, id: string, position: Vec2, color?: THREE.ColorRepresentation): THREE.Group {
  const palette = getPalette(world);
  const group = new THREE.Group();
  group.name = id;
  const flagColor = color ?? toColor(palette.accent);
  const stoneMat = createCelMaterial({
    color: toColor(palette.platformEdge.clone().lerp(palette.ink, 0.3)),
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.42,
    specularBand: 0.88,
    specularStrength: 0.1,
  });
  const poleMat = createCelMaterial({
    color: toColor(palette.ink.clone().lerp(new THREE.Color('#a08a62'), 0.4)),
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.44,
    specularStrength: 0.12,
  });
  const flagMat = createCelMaterial({
    color: flagColor,
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.52,
    specularBand: 0.78,
    specularStrength: 0.3,
  });

  const base = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.36, 0.22, 6), stoneMat);
  base.name = `${id}_base`;
  base.position.set(position.x, position.y + 0.11, 0.78);
  group.add(base);
  attachOutline(group, base, palette.ink, 0.016);

  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.05, 1.62, 6), poleMat);
  pole.name = `${id}_pole`;
  pole.position.set(position.x, position.y + 0.95, 0.78);
  group.add(pole);
  attachOutline(group, pole, palette.ink, 0.008);

  const pennant = new THREE.Mesh(new THREE.ConeGeometry(0.23, 0.62, 4), flagMat);
  pennant.name = `${id}_pennant`;
  pennant.rotation.z = -Math.PI * 0.5;
  pennant.rotation.x = Math.PI * 0.25;
  pennant.position.set(position.x + 0.34, position.y + 1.56, 0.78);
  pennant.scale.set(0.85, 1, 0.32);
  group.add(pennant);
  attachOutline(group, pennant, palette.ink, 0.012);

  const finial = new THREE.Mesh(new THREE.SphereGeometry(0.06, 10, 8), flagMat);
  finial.name = `${id}_finial`;
  finial.position.set(position.x, position.y + 1.8, 0.78);
  group.add(finial);
  attachOutline(group, finial, palette.ink, 0.006);
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

/**
 * Visually brands a World 2 portal as the true gate (gold glow) or a decoy (red rim).
 * Unlit materials read as emissive against the cel-shaded frame.
 */
function applyPortalFateMarking(portal: ArenaPortal, correct: boolean): void {
  const centerY = portal.position.y + 0.8;
  if (correct) {
    const glowMat = new THREE.MeshBasicMaterial({ color: '#ffd76e', transparent: true, opacity: 0.85 });
    const glowRing = new THREE.Mesh(new THREE.TorusGeometry(0.66, 0.055, 8, 30), glowMat);
    glowRing.name = `${portal.id}_gold_glow_ring`;
    glowRing.position.set(portal.position.x, centerY, 0.9);
    portal.mesh.add(glowRing);

    const haloMat = new THREE.MeshBasicMaterial({ color: '#fff2bc', transparent: true, opacity: 0.28, depthWrite: false });
    const halo = new THREE.Mesh(new THREE.CircleGeometry(0.62, 26), haloMat);
    halo.name = `${portal.id}_gold_halo`;
    halo.position.set(portal.position.x, centerY, 0.88);
    portal.mesh.add(halo);
    portal.mesh.userData.fate = 'right';
    return;
  }

  const rimMat = new THREE.MeshBasicMaterial({ color: '#ff4a58', transparent: true, opacity: 0.9 });
  const rim = new THREE.Mesh(new THREE.TorusGeometry(0.6, 0.03, 6, 26), rimMat);
  rim.name = `${portal.id}_red_rim`;
  rim.position.set(portal.position.x, centerY, 0.9);
  portal.mesh.add(rim);
  portal.mesh.userData.fate = 'wrong';
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
  addCloudSea(root, world, floor, bounds);
  addParallaxBackdrop(root, world, floor, bounds);
  addAmbientMotes(root, world, floor, bounds);
  addLedgeProps(root, world, platforms);
  if (world === 1) addWorldOneIceDecor(root, floor, platforms, bounds);
  else if (world === 2) addWorldTwoVoidDecor(root, floor, bounds);
  else if (world === 3) addWorldThreeForgeDecor(root, floor, platforms, bounds);
  else addWorldFourDiceDecor(root, floor, bounds);
}

/**
 * Graphic underworld: banks of cel cumulus massed below the lowest platform.
 * A vertical arena spends much of its framing looking down at nothing, and the
 * sky gradient bottoms out into a single pale value there — so the lower third
 * of the frame ends up an empty field. Filling it with the same lobed cloud
 * language the dome uses gives the drop real depth. Purely decorative: nothing
 * here enters the platform list, so the sea is never standable.
 */
function addCloudSea(root: THREE.Group, world: WorldId, floor: number, bounds: AABB): void {
  const palette = getPalette(world);
  // No ink on these. A bank is one mass built from many overlapping lobes, and
  // an inverted hull per lobe draws a contour along every internal seam — which
  // is exactly what turns a cloud bank into a pile of boulders. The dome's sea
  // carries the outlined horizon; these near banks read on value alone.
  //
  // Recession pulls toward the sky's own mid tone rather than fog, so the banks
  // land clearly below the white platforms instead of competing with them.
  const recessionTarget = palette.fog.clone().lerp(palette.skyMid, 0.45);
  const layerSpecs = [
    { z: -7.5, recede: 0.42, speed: 0.1, ampX: 0.9, ampY: 0.22, drop: 3.2, scale: 0.95, lobes: 11, ambient: 0.8 },
    { z: -11.0, recede: 0.62, speed: 0.07, ampX: 1.5, ampY: 0.34, drop: 7.0, scale: 1.45, lobes: 10, ambient: 0.86 },
    { z: -15.0, recede: 0.8, speed: 0.045, ampX: 2.3, ampY: 0.5, drop: 12.0, scale: 2.1, lobes: 9, ambient: 0.92 },
  ];

  for (let li = 0; li < layerSpecs.length; li++) {
    const spec = layerSpecs[li]!;
    const layer = makeParallaxLayer(root, `w${world}_cloud_sea_${li}`, spec.z, {
      baseX: 0,
      baseY: 0,
      ampX: spec.ampX,
      ampY: spec.ampY,
      speed: spec.speed,
      phase: li * 1.3 + floor * 0.5,
    });
    const lit = palette.cloud.clone().lerp(recessionTarget, spec.recede);
    // Shadow pulled most of the way back to the lit value. Cloud is a bright
    // mass with a shelf under it, not a lit-and-shadowed solid — give a sphere
    // a full toon terminator and it stops being cloud and becomes a boulder.
    const shade = palette.cloudShadow.clone().lerp(lit, 0.25).lerp(recessionTarget, spec.recede);
    const mat = createCelMaterial({
      color: toColor(lit),
      rimColor: palette.rim,
      fillColor: toColor(lit),
      shadowTint: toColor(shade),
      shadowBias: 0.24,
      matcapMix: 0,
      ambient: spec.ambient,
      specularStrength: 0,
      rimStrength: 0,
    });
    // Coarse segment counts on purpose: the toon ramp needs facets to break
    // against, and a smooth sphere gives it one unbroken terminator.
    const geometry = new THREE.SphereGeometry(1, 10, 6);

    // Two banks per layer, staggered in height, so the sea has a horizon of its
    // own rather than one ruled line of identical puffs.
    for (let b = 0; b < 2; b++) {
      const bankJ = decorJitter(li * 13 + b, floor + 3);
      const bankY = bounds.y - spec.drop - bankJ * spec.scale * 1.4 + b * spec.scale * 1.1;
      const span = bounds.w * (1.5 + spec.recede * 1.4);
      const originX = bounds.x + bounds.w * 0.5 - span * 0.5;
      for (let i = 0; i < spec.lobes; i++) {
        const j = decorJitter(li * 29 + b * 5 + i, floor);
        const k = decorJitter(li * 53 + b * 7 + i, floor + 11);
        // Lobes overlap hard — a bank is one mass with a lumpy crown, not a row
        // of separate balls. Radius swings wide so the crown never rhythms, and
        // the vertical jitter stays under half a radius: lift a lobe clear of
        // its neighbours and the bank stops being cloud and becomes boulders.
        const radius = spec.scale * (1.4 + j * 1.3);
        const t = (i + 0.5) / spec.lobes;
        const lobe = new THREE.Mesh(geometry, mat);
        lobe.name = `w${world}_cloud_sea_lobe_${li}_${b}_${i}`;
        lobe.position.set(
          originX + span * t + (k - 0.5) * spec.scale * 0.5,
          bankY + (k - 0.5) * radius * 0.42,
          (j - 0.5) * spec.scale,
        );
        // Flattened toward the camera plane so the bank stays a graphic
        // silhouette instead of bulging into a row of spheres.
        lobe.scale.set(radius, radius * 0.72, radius * 0.55);
        layer.add(lobe);
      }
    }
  }
}

/**
 * Three drifting depth layers of columnar spires. Columns rather than wide
 * slabs is the load-bearing decision: a vertical arena's camera travels up, so
 * the backdrop has to run full height while still leaving vertical gaps for the
 * sky. Wide slabs wall the sky off entirely and turn every frame into flat
 * blocking colour.
 */
function addParallaxBackdrop(root: THREE.Group, world: WorldId, floor: number, bounds: AABB): void {
  const palette = getPalette(world);
  const ink = toColor(palette.ink.clone().lerp(palette.skyMid, 0.22));
  // Distant geometry approaches the sky colour — that is what aerial
  // perspective actually does. Lerping toward black is what reads as graybox.
  const recessionTarget = palette.skyMid.clone().lerp(palette.fog, 0.45);
  // Sparse and narrow on purpose: the backdrop punctuates the skyline, it does
  // not replace it. Coverage above roughly a third of the frame turns every
  // shot into flat blocking colour.
  const layerSpecs = [
    { z: -4.6, recede: 0.22, ampX: 0.12, ampY: 0.06, speed: 0.22, columns: 3, widthK: 0.062, ambient: 0.34, top: 0.42, ink: 0.018 },
    { z: -8.0, recede: 0.5, ampX: 0.22, ampY: 0.1, speed: 0.15, columns: 3, widthK: 0.052, ambient: 0.52, top: 0.6, ink: 0.011 },
    { z: -12.0, recede: 0.74, ampX: 0.34, ampY: 0.16, speed: 0.09, columns: 4, widthK: 0.044, ambient: 0.8, top: 0.76, ink: 0.006 },
  ];

  for (let li = 0; li < layerSpecs.length; li++) {
    const spec = layerSpecs[li]!;
    const layer = makeParallaxLayer(root, `w${world}_parallax_layer_${li}`, spec.z, {
      baseX: 0,
      baseY: 0,
      ampX: spec.ampX,
      ampY: spec.ampY,
      speed: spec.speed,
      phase: li * 2.1 + floor * 0.7,
    });
    const toneA = palette.platform.clone().lerp(recessionTarget, spec.recede);
    const toneB = palette.platformEdge.clone().lerp(recessionTarget, spec.recede);

    for (let i = 0; i < spec.columns; i++) {
      const j = decorJitter(li * 7 + i, floor);
      const k = decorJitter(li * 19 + i, floor + 5);
      const width = bounds.w * spec.widthK * (0.7 + j * 0.75);
      // Columns start well below frame and stop at staggered heights so the
      // upper arena still shows sky when the camera climbs.
      const baseY = bounds.y - 3.0;
      const topY = bounds.y + bounds.h * (0.12 + k * spec.top);
      const height = Math.max(2.0, topY - baseY);
      // Bias columns toward the flanks so the play space keeps sky behind it.
      const spread = (i + 0.5) / spec.columns - 0.5;
      const x = bounds.x + bounds.w * (0.5 + spread * 1.7) + (j - 0.5) * bounds.w * 0.06;
      const mat = createCelMaterial({
        color: toColor((i + li) % 2 === 0 ? toneA : toneB),
        rimColor: palette.rim,
        fillColor: palette.fillLight,
        shadowTint: palette.ramp[0],
        shadowBias: 0.35,
        matcapMix: 0,
        ambient: spec.ambient,
        specularStrength: 0,
        rimStrength: li === 0 ? 0.14 : 0,
      });

      // Five-sided tapered shaft rather than a box: the camera catches three
      // faces at once, so the toon ramp splits each spire into its own value
      // bands. A flat box front-on is what reads as a pasted blue bar.
      const shaft = new THREE.Mesh(
        new THREE.CylinderGeometry(width * 0.34, width * 0.62, height, 5, 1),
        mat,
      );
      shaft.name = `w${world}_backdrop_spire_${li}_${i}`;
      shaft.position.set(x, baseY + height * 0.5, 0);
      shaft.rotation.y = j * Math.PI * 0.4;
      shaft.rotation.z = (j - 0.5) * 0.05;
      layer.add(shaft);
      if (spec.ink > 0) attachOutline(layer, shaft, ink, spec.ink);

      // Angular cap so the silhouette peaks instead of ending in a flat bar.
      const cap = new THREE.Mesh(new THREE.ConeGeometry(width * 0.38, width * (1.1 + k * 1.6), 5), mat);
      cap.name = `w${world}_backdrop_spire_cap_${li}_${i}`;
      cap.position.set(x, baseY + height + width * (0.55 + k * 0.8), 0);
      cap.rotation.set(0, shaft.rotation.y, shaft.rotation.z);
      layer.add(cap);
      if (spec.ink > 0) attachOutline(layer, cap, ink, spec.ink);
    }
  }
}

/**
 * Ambient atmosphere: 14 hard-edged cel diamonds drifting on two slow
 * parallax layers behind the play space. Unlit flat color so they read as
 * sparkle motes, tinted per world palette. Deterministic via decorJitter.
 */
function addAmbientMotes(root: THREE.Group, world: WorldId, floor: number, bounds: AABB): void {
  const palette = getPalette(world);
  const tints = [toColor(palette.rim), toColor(palette.accent)];
  const moteInk = toColor(palette.ink);
  const layerSpecs = [
    { z: -2.4, speed: 0.14, ampX: 0.85, ampY: 0.5, count: 7, size: 0.1, opacity: 0.95, ink: 0.012 },
    { z: -5.0, speed: 0.09, ampX: 1.35, ampY: 0.75, count: 7, size: 0.14, opacity: 0.72, ink: 0.009 },
  ];
  for (let li = 0; li < layerSpecs.length; li++) {
    const spec = layerSpecs[li]!;
    const layer = makeParallaxLayer(root, `w${world}_ambient_motes_${li}`, spec.z, {
      baseX: 0,
      baseY: 0,
      ampX: spec.ampX,
      ampY: spec.ampY,
      speed: spec.speed,
      phase: li * 1.7 + floor * 1.3,
    });
    const geometry = new THREE.OctahedronGeometry(spec.size, 0);
    for (let i = 0; i < spec.count; i++) {
      const jx = decorJitter(li * 31 + i, floor);
      const jy = decorJitter(li * 47 + i, floor + 9);
      const mote = new THREE.Mesh(
        geometry,
        new THREE.MeshBasicMaterial({
          color: tints[i % 2]!,
          transparent: true,
          opacity: spec.opacity * (0.7 + jx * 0.3),
          depthWrite: false,
        }),
      );
      mote.name = `w${world}_ambient_mote_${li}_${i}`;
      // Kept in the upper sky where the gradient is deep. Warm motes scattered
      // across the pale lower band read as dust on the lens, not atmosphere.
      mote.position.set(
        bounds.x + 0.5 + jx * (bounds.w - 1),
        bounds.y + bounds.h * (0.42 + jy * 0.56),
        0,
      );
      mote.scale.y = 1.55;
      mote.rotation.z = (jy - 0.5) * 0.9;
      layer.add(mote);
      // Ink contour so a mote drifting across a white cloud still reads.
      attachOutline(layer, mote, moteInk, spec.ink);
    }
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

  let placed = 0;
  for (let i = 0; i < platforms.length; i++) {
    const platform = platforms[i]!;
    if (platform.aabb.w < 3.4 || i % 2 !== 0 || placed >= 2) continue;
    const side = i % 4 === 0 ? -1 : 1;
    const position = {
      x: platform.aabb.x + platform.aabb.w * (side < 0 ? 0.16 : 0.84),
      y: platform.topY,
    };
    const isBarrel = placed % 2 === 0;
    const prop = createKayKitProp(
      isBarrel ? KAYKIT_PROPS.barrelSmall : KAYKIT_PROPS.crateLarge,
      `${platform.id}_${isBarrel ? 'barrel' : 'crate'}_${i}`,
      position,
      isBarrel ? 0.72 : 0.58,
      0.78,
    );
    if (prop) {
      prop.userData.interactive = false;
      root.add(prop);
      placed++;
      continue;
    }

    createOutlinedBox(
      root,
      `${platform.id}_ledge_prop_${i}`,
      new THREE.Vector3(0.38 + (i % 3) * 0.12, 0.16, 0.42),
      new THREE.Vector3(
        position.x,
        platform.topY + 0.1,
        1.24,
      ),
      propMat,
      palette.ink,
      0.014,
    );
    placed++;
  }
}

function addWorldOneIceDecor(root: THREE.Group, floor: number, platforms: readonly ArenaPlatform[], bounds: AABB): void {
  const palette = getPalette(1);
  // Frost temperature split: cyan-white lights against blue-violet shadows.
  const iceMat = createCelMaterial({
    color: '#bfe8fb',
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    shadowTint: '#4a6f9c',
    shadowBias: 0.68,
    texture: 'ice',
    texScale: 0.55,
    texStrength: 0.38,
    matcapMix: 0.24,
    ambient: 0.5,
    specularBand: 0.68,
    specularStrength: 0.5,
  });
  const snowMat = createCelMaterial({
    color: '#ffffff',
    rimColor: '#fff0bc',
    fillColor: '#8fc4e8',
    shadowTint: '#7fa6c8',
    shadowBias: 0.6,
    matcapMix: 0.04,
    ambient: 0.74,
    specularBand: 0.86,
    specularStrength: 0.16,
  });
  // Mid-depth ridges recede toward the sky, so they read as distance rather
  // than as a dark wall behind the play space.
  const shadowMat = createCelMaterial({
    color: '#93bcdd',
    rimColor: '#eaf4fb',
    fillColor: palette.fillLight,
    shadowTint: '#6f9ac4',
    shadowBias: 0.4,
    texture: 'stone',
    texScale: 0.18,
    texStrength: 0.16,
    matcapMix: 0,
    ambient: 0.72,
    specularStrength: 0,
    rimStrength: 0.12,
  });

  // Chunky twin-spire ice pillars behind the walkable spans
  for (let i = 0; i < Math.min(5, platforms.length); i++) {
    const platform = platforms[i]!;
    const pillarHeight = 1.7 + ((floor + i) % 3) * 0.6;
    const pillar = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.46, pillarHeight, 6), iceMat);
    pillar.name = `${platform.id}_ice_pillar_${i}`;
    pillar.position.set(platform.aabb.x + platform.aabb.w * (0.22 + (i % 2) * 0.48), platform.topY + pillarHeight * 0.5, -1.05);
    pillar.rotation.z = (i % 2 === 0 ? -1 : 1) * 0.08;
    root.add(pillar);
    attachOutline(root, pillar, palette.ink, 0.024);

    const spire = new THREE.Mesh(new THREE.ConeGeometry(0.26, 0.85, 6), iceMat);
    spire.name = `${platform.id}_ice_spire_${i}`;
    spire.position.set(pillar.position.x, platform.topY + pillarHeight + 0.4, -1.05);
    spire.rotation.z = pillar.rotation.z;
    root.add(spire);
    attachOutline(root, spire, palette.ink, 0.018);
  }

  // Snow mounds capping alternating ledges
  for (let i = 0; i < platforms.length; i += 2) {
    const platform = platforms[i]!;
    const mound = new THREE.Mesh(new THREE.SphereGeometry(0.42 + decorJitter(i, floor) * 0.2, 10, 6), snowMat);
    mound.name = `${platform.id}_snow_mound_${i}`;
    mound.position.set(platform.aabb.x + platform.aabb.w * 0.68, platform.topY + 0.05, -0.72);
    mound.scale.y = 0.34;
    root.add(mound);
    attachOutline(root, mound, palette.ink, 0.012);
  }

  // Heavier hanging icicles across the ceiling line
  for (let i = 0; i < 8; i++) {
    const icicle = new THREE.Mesh(new THREE.ConeGeometry(0.18 + (i % 2) * 0.07, 1.1 + (i % 3) * 0.38, 5), iceMat);
    icicle.name = `w1_hanging_icicle_${i}`;
    icicle.rotation.z = Math.PI;
    icicle.position.set(bounds.x + 1.2 + i * (bounds.w - 2.4) / 7, bounds.y + bounds.h - 0.7 - (i % 2) * 0.35, -1.4);
    root.add(icicle);
    attachOutline(root, icicle, palette.ink, 0.018);
  }

  // Mid-depth ice ridges: narrow angular peaks that punctuate the skyline
  // rather than wide blocks that erase it.
  for (let i = 0; i < 4; i++) {
    const j = decorJitter(i + 70, floor);
    const w = 1.5 + j * 1.3;
    const h = 3.2 + j * 3.4;
    const ridge = new THREE.Mesh(new THREE.ConeGeometry(w, h, 4), shadowMat);
    ridge.name = `w1_ice_ridge_${i}`;
    ridge.position.set(bounds.x + bounds.w * (0.1 + i * 0.27 + j * 0.06), bounds.y + h * 0.4 + j * 2.2, -6.6 - i * 0.45);
    ridge.rotation.set(0, Math.PI * 0.25, (j - 0.5) * 0.12);
    root.add(ridge);
    attachOutline(root, ridge, palette.ink, 0.014);
  }
}

/** World 2: floating shard clusters, portal frames, star-curtain backdrop. */
function addWorldTwoVoidDecor(root: THREE.Group, floor: number, bounds: AABB): void {
  const palette = getPalette(2);
  const magentaMat = createCelMaterial({
    color: '#e040a0',
    rimColor: '#ff8ad0',
    fillColor: '#5a1a6a',
    ambient: 0.52,
    specularBand: 0.78,
    specularStrength: 0.4,
  });
  const tealMat = createCelMaterial({
    color: '#3ec8c0',
    rimColor: '#a8fff2',
    fillColor: '#0e4a52',
    ambient: 0.52,
    specularBand: 0.78,
    specularStrength: 0.4,
  });
  const slabMat = createCelMaterial({
    color: '#1c2140',
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.44,
    specularStrength: 0.08,
  });
  const starMat = createCelMaterial({
    color: '#f4f8ff',
    rimColor: '#b8fff5',
    fillColor: '#4a3a7a',
    ambient: 0.72,
    specularStrength: 0.1,
  });

  // Floating shard clusters drifting at the arena flanks
  for (let i = 0; i < 6; i++) {
    const j = decorJitter(i, floor);
    const accent = i % 2 === 0 ? magentaMat : tealMat;
    const cluster = new THREE.Group();
    cluster.name = `w2_shard_cluster_${i}`;
    const cx = bounds.x + bounds.w * (i % 2 === 0 ? 0.06 + j * 0.16 : 0.78 + j * 0.16);
    const cy = bounds.y + 1.2 + (i / 6) * (bounds.h - 2.0) + (j - 0.5) * 0.8;
    const cz = -1.8 - j * 1.8;
    const core = new THREE.Mesh(new THREE.OctahedronGeometry(0.36 + j * 0.22), accent);
    core.name = `w2_shard_core_${i}`;
    core.rotation.z = j * Math.PI;
    cluster.add(core);
    attachOutline(cluster, core, palette.ink, 0.016);
    for (let s = 0; s < 2; s++) {
      const chip = new THREE.Mesh(new THREE.TetrahedronGeometry(0.14 + s * 0.07), accent);
      chip.name = `w2_shard_chip_${i}_${s}`;
      chip.position.set((s === 0 ? -0.5 : 0.44) + j * 0.2, 0.34 - s * 0.62, (s === 0 ? 0.2 : -0.24));
      chip.rotation.set(j * 2, s * 1.3, j);
      cluster.add(chip);
      attachOutline(cluster, chip, palette.ink, 0.01);
    }
    cluster.position.set(cx, cy, cz);
    root.add(cluster);
  }

  // Portal frames standing in the mid-depth
  for (let i = 0; i < 2; i++) {
    const px = bounds.x + bounds.w * (i === 0 ? 0.24 : 0.76);
    const py = bounds.y + bounds.h * (0.3 + i * 0.32);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(1.05 + i * 0.25, 0.11, 8, 26), i === 0 ? magentaMat : tealMat);
    ring.name = `w2_portal_frame_${i}`;
    ring.position.set(px, py, -4.6 - i * 1.2);
    ring.rotation.y = (i === 0 ? 1 : -1) * 0.3;
    root.add(ring);
    attachOutline(root, ring, palette.ink, 0.02);
    const innerDisc = new THREE.Mesh(new THREE.CircleGeometry(0.92 + i * 0.22, 20), slabMat);
    innerDisc.name = `w2_portal_disc_${i}`;
    innerDisc.position.set(px, py, -4.65 - i * 1.2);
    innerDisc.rotation.y = ring.rotation.y;
    root.add(innerDisc);
  }

  // Star-curtain: tall dark slabs studded with bright star chips, far depth
  for (let i = 0; i < 3; i++) {
    const j = decorJitter(i + 20, floor);
    const curtain = new THREE.Mesh(
      new THREE.BoxGeometry(bounds.w * 0.24, bounds.h * (0.5 + j * 0.3), 0.18),
      slabMat,
    );
    curtain.name = `w2_star_curtain_${i}`;
    curtain.position.set(bounds.x + bounds.w * (0.16 + i * 0.34), bounds.y + bounds.h * (0.4 + j * 0.25), -12.2);
    curtain.rotation.z = (j - 0.5) * 0.1;
    root.add(curtain);
  }
  for (let i = 0; i < 22; i++) {
    const jx = decorJitter(i + 40, floor);
    const jy = decorJitter(i + 60, floor);
    const star = new THREE.Mesh(new THREE.OctahedronGeometry(0.05 + jx * 0.06), starMat);
    star.name = `w2_star_${i}`;
    star.position.set(bounds.x + jx * bounds.w, bounds.y + 0.5 + jy * (bounds.h + 3), -11.8);
    star.rotation.z = jx * Math.PI;
    root.add(star);
  }
}

/** World 3: pistons, glow strips, coil stacks, ember columns. */
function addWorldThreeForgeDecor(root: THREE.Group, floor: number, platforms: readonly ArenaPlatform[], bounds: AABB): void {
  const palette = getPalette(3);
  const ironMat = createCelMaterial({
    color: '#4a4034',
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.42,
    specularBand: 0.84,
    specularStrength: 0.3,
  });
  const glowMat = createCelMaterial({
    color: '#ffb020',
    rimColor: '#ffe9a0',
    fillColor: '#c04808',
    ambient: 0.78,
    specularBand: 0.7,
    specularStrength: 0.5,
  });
  const emberMat = createCelMaterial({
    color: '#ff6a2a',
    rimColor: '#ffd080',
    fillColor: '#802008',
    ambient: 0.7,
    specularStrength: 0.2,
  });
  const coilMat = createCelMaterial({
    color: '#2060d0',
    rimColor: '#60c0ff',
    fillColor: palette.fillLight,
    ambient: 0.5,
    specularBand: 0.76,
    specularStrength: 0.45,
  });

  // Pistons pumping behind alternating spans
  for (let i = 0; i < platforms.length; i += 2) {
    const platform = platforms[i]!;
    const j = decorJitter(i, floor);
    const shaftHeight = 1.5 + j * 1.1;
    const px = platform.aabb.x + platform.aabb.w * 0.5;
    const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, shaftHeight, 8), ironMat);
    shaft.name = `${platform.id}_piston_shaft`;
    shaft.position.set(px, platform.topY + shaftHeight * 0.5, -1.7);
    root.add(shaft);
    attachOutline(root, shaft, palette.ink, 0.016);
    const head = new THREE.Mesh(new THREE.BoxGeometry(0.72, 0.4, 0.6), ironMat);
    head.name = `${platform.id}_piston_head`;
    head.position.set(px, platform.topY + shaftHeight + 0.2, -1.7);
    root.add(head);
    attachOutline(root, head, palette.ink, 0.018);
    const headGlow = new THREE.Mesh(new THREE.BoxGeometry(0.76, 0.09, 0.64), glowMat);
    headGlow.name = `${platform.id}_piston_glow`;
    headGlow.position.set(px, platform.topY + shaftHeight - 0.05, -1.7);
    root.add(headGlow);
  }

  // Molten glow strips along every other platform's front lip
  for (let i = 1; i < platforms.length; i += 2) {
    const platform = platforms[i]!;
    const strip = new THREE.Mesh(
      new THREE.BoxGeometry(platform.aabb.w * 0.82, 0.07, 0.1),
      glowMat,
    );
    strip.name = `${platform.id}_glow_strip`;
    strip.position.set(platform.aabb.x + platform.aabb.w * 0.5, platform.topY - platform.aabb.h * 0.5, 1.18);
    root.add(strip);
  }

  // Coil stacks — stacked tori on a dark core, arcing tesla-blue
  for (let i = 0; i < 2; i++) {
    const cx = bounds.x + bounds.w * (i === 0 ? 0.2 : 0.82);
    const baseY = bounds.y + 0.6;
    const core = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.26, 2.6, 8), ironMat);
    core.name = `w3_coil_core_${i}`;
    core.position.set(cx, baseY + 1.3, -3.2);
    root.add(core);
    attachOutline(root, core, palette.ink, 0.018);
    for (let c = 0; c < 3; c++) {
      const coil = new THREE.Mesh(new THREE.TorusGeometry(0.4 - c * 0.06, 0.075, 8, 18), coilMat);
      coil.name = `w3_coil_ring_${i}_${c}`;
      coil.rotation.x = Math.PI * 0.5;
      coil.position.set(cx, baseY + 0.7 + c * 0.75, -3.2);
      root.add(coil);
      attachOutline(root, coil, palette.ink, 0.012);
    }
    const tip = new THREE.Mesh(new THREE.SphereGeometry(0.18, 10, 8), glowMat);
    tip.name = `w3_coil_tip_${i}`;
    tip.position.set(cx, baseY + 2.75, -3.2);
    root.add(tip);
  }

  // Ember columns rising in the background haze
  for (let i = 0; i < 4; i++) {
    const j = decorJitter(i + 10, floor);
    const column = new THREE.Mesh(new THREE.ConeGeometry(0.16 + j * 0.1, 2.2 + j * 1.6, 5), emberMat);
    column.name = `w3_ember_column_${i}`;
    column.position.set(bounds.x + bounds.w * (0.12 + i * 0.25), bounds.y + 1.4 + j * 1.4, -5.4 - j);
    root.add(column);
    for (let e = 0; e < 2; e++) {
      const mote = new THREE.Mesh(new THREE.SphereGeometry(0.07 + e * 0.03, 8, 6), emberMat);
      mote.name = `w3_ember_mote_${i}_${e}`;
      mote.position.set(column.position.x + (e === 0 ? 0.3 : -0.24), column.position.y + 1.5 + e * 0.7, column.position.z);
      root.add(mote);
    }
  }
}

/** World 4: giant pip cubes, tilted card monoliths, gold trim arches. */
function addWorldFourDiceDecor(root: THREE.Group, floor: number, bounds: AABB): void {
  const palette = getPalette(4);
  const ivoryMat = createCelMaterial({
    color: '#f4ecda',
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.55,
    specularBand: 0.82,
    specularStrength: 0.28,
  });
  const pipMat = createCelMaterial({
    color: '#2c1c38',
    rimColor: palette.rim,
    fillColor: palette.fillLight,
    ambient: 0.4,
    specularStrength: 0.08,
  });
  const goldMat = createCelMaterial({
    color: '#ffd23e',
    rimColor: '#fff2c0',
    fillColor: '#8a5820',
    ambient: 0.58,
    specularBand: 0.74,
    specularStrength: 0.5,
  });
  const cardMat = createCelMaterial({
    color: '#efe4ce',
    rimColor: palette.rim,
    fillColor: '#7a4a84',
    ambient: 0.52,
    specularStrength: 0.14,
  });

  // Giant pip cubes suspended behind the shards
  const pipLayouts: ReadonlyArray<ReadonlyArray<readonly [number, number]>> = [
    [[0, 0]],
    [[-0.3, 0.3], [0.3, -0.3]],
    [[-0.3, 0.3], [0, 0], [0.3, -0.3]],
    [[-0.3, 0.3], [0.3, 0.3], [-0.3, -0.3], [0.3, -0.3]],
    [[-0.3, 0.3], [0.3, 0.3], [0, 0], [-0.3, -0.3], [0.3, -0.3]],
  ];
  for (let i = 0; i < 3; i++) {
    const j = decorJitter(i, floor);
    const size = 1.5 + j * 0.7;
    const cube = new THREE.Group();
    cube.name = `w4_pip_cube_${i}`;
    const body = new THREE.Mesh(new THREE.BoxGeometry(size, size, size), ivoryMat);
    body.name = `w4_pip_cube_body_${i}`;
    cube.add(body);
    attachOutline(cube, body, palette.ink, 0.024);
    const faceValue = 1 + Math.floor(j * 4.999);
    const layout = pipLayouts[faceValue - 1]!;
    for (let p = 0; p < layout.length; p++) {
      const offset = layout[p]!;
      const pip = new THREE.Mesh(new THREE.CylinderGeometry(size * 0.09, size * 0.09, 0.05, 12), pipMat);
      pip.name = `w4_pip_${i}_${p}`;
      pip.rotation.x = Math.PI * 0.5;
      pip.position.set(offset[0] * size, offset[1] * size, size * 0.5 + 0.03);
      cube.add(pip);
    }
    cube.position.set(
      bounds.x + bounds.w * (0.14 + i * 0.36),
      bounds.y + bounds.h * (0.22 + j * 0.5),
      -4.4 - i * 0.9,
    );
    cube.rotation.z = (j - 0.5) * 0.5;
    cube.rotation.y = (j - 0.5) * 0.4;
    root.add(cube);
  }

  // Tilted card monoliths with gold trim frames
  for (let i = 0; i < 3; i++) {
    const j = decorJitter(i + 30, floor);
    const cx = bounds.x + bounds.w * (0.22 + i * 0.28) + (j - 0.5);
    const cy = bounds.y + bounds.h * (0.3 + j * 0.34);
    const cz = -6.4 - i * 0.8;
    const tilt = (j - 0.5) * 0.34;
    const card = new THREE.Mesh(new THREE.BoxGeometry(1.5, 3.3, 0.12), cardMat);
    card.name = `w4_card_monolith_${i}`;
    card.position.set(cx, cy, cz);
    card.rotation.z = tilt;
    root.add(card);
    attachOutline(root, card, palette.ink, 0.02);
    const trim = new THREE.Mesh(new THREE.BoxGeometry(1.66, 3.46, 0.08), goldMat);
    trim.name = `w4_card_trim_${i}`;
    trim.position.set(cx, cy, cz - 0.06);
    trim.rotation.z = tilt;
    root.add(trim);
    const sigil = new THREE.Mesh(new THREE.OctahedronGeometry(0.3), goldMat);
    sigil.name = `w4_card_sigil_${i}`;
    sigil.position.set(cx, cy + 0.8, cz + 0.1);
    sigil.rotation.z = tilt;
    root.add(sigil);
  }

  // Gold trim arches spanning the mid-depth
  for (let i = 0; i < 2; i++) {
    const arch = new THREE.Mesh(new THREE.TorusGeometry(1.6 + i * 0.4, 0.13, 8, 24, Math.PI), goldMat);
    arch.name = `w4_gold_arch_${i}`;
    arch.position.set(bounds.x + bounds.w * (i === 0 ? 0.3 : 0.72), bounds.y + bounds.h * (0.24 + i * 0.36), -3.0 - i * 0.8);
    root.add(arch);
    attachOutline(root, arch, palette.ink, 0.018);
    for (const side of [-1, 1]) {
      const post = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.18, 1.1, 8), ivoryMat);
      post.name = `w4_arch_post_${i}_${side < 0 ? 'l' : 'r'}`;
      post.position.set(arch.position.x + side * (1.6 + i * 0.4), arch.position.y - 0.55, arch.position.z);
      root.add(post);
      attachOutline(root, post, palette.ink, 0.014);
    }
  }
}

function createRewardChest(arena: Arena): THREE.Group {
  const name = `w${arena.world}_f${arena.floor}_chest`;
  const preferredUrl = arena.floor === 5 ? KAYKIT_PROPS.chestGold : KAYKIT_PROPS.chest;
  const chestUrl = hasCachedGLTF(preferredUrl) ? preferredUrl : KAYKIT_PROPS.chest;
  const chest = createKayKitProp(chestUrl, name, arena.chest, 1.1, 0.78);
  if (chest) {
    chest.userData.interactionPoint = cloneVec2(arena.chest);
    return chest;
  }
  return createMarker(arena.world, name, arena.chest);
}

function addArenaMarkers(arena: Arena): void {
  arena.root.add(createRewardChest(arena));
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
  correctPortalId: string | null = null,
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
    correctPortalId,
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

  // Boss floor: ascension flow anchored to real platform AABBs — charge on mid tiers, deliver beside the boss perch.
  const chargeStations: Vec2[] = [];
  const sockets: Vec2[] = [];
  if (floor === 5) {
    const midLow = platforms[Math.floor(platforms.length * 0.35)]!;
    const midHigh = platforms[Math.floor(platforms.length * 0.65)]!;
    chargeStations.push(
      { x: midLow.aabb.x + midLow.aabb.w * 0.5, y: midLow.topY },
      { x: midHigh.aabb.x + midHigh.aabb.w * 0.5, y: midHigh.topY },
    );
    sockets.push({ x: top.aabb.x + top.aabb.w * 0.24, y: top.topY });
  }
  return makeArena(1, floor, platforms, player, enemyAnchors, chest, gate, chargeStations, sockets);
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

  // Seed which portal is the true gate deterministically from the layout rng, then brand each door.
  const correctPortalIndex = Math.min(portals.length - 1, Math.floor(rng() * portals.length));
  const correctPortalId = portals[correctPortalIndex]?.id ?? null;
  for (const portal of portals) {
    applyPortalFateMarking(portal, portal.id === correctPortalId);
  }

  const enemyAnchors = platforms.slice(1).map((p, i) => ({ x: p.aabb.x + p.aabb.w * (i % 2 === 0 ? 0.65 : 0.35), y: p.topY }));
  const player = { x: platforms[0]!.aabb.x + 0.7, y: platforms[0]!.topY };
  const top = platforms[platforms.length - 1]!;
  const chest = { x: top.aabb.x + top.aabb.w * 0.42, y: top.topY };
  const gate = createPortal(2, `w2_f${floor}_door_gate`, 'door', { x: top.aabb.x + top.aabb.w - 0.75, y: top.topY }, true, 2, floor + 1);
  return makeArena(2, floor, platforms, player, enemyAnchors, chest, gate, chargeStations, sockets, portals, lanes, correctPortalId);
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

  // Boss floor: charge stations on mid forge spans so the carry crosses the lanes.
  const chargeStations: Vec2[] = [];
  if (floor === 5) {
    const midA = platforms[Math.floor(platforms.length * 0.35)]!;
    const midB = platforms[Math.floor(platforms.length * 0.6)]!;
    chargeStations.push(
      { x: midA.aabb.x + midA.aabb.w * 0.5, y: midA.topY },
      { x: midB.aabb.x + midB.aabb.w * 0.5, y: midB.topY },
    );
  }
  return makeArena(3, floor, platforms, player, enemyAnchors, chest, gate, chargeStations, sockets);
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
