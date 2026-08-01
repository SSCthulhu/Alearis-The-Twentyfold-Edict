import * as THREE from 'three';
import { attachOutline, createCelMaterial } from '../render/CelMaterial';
import type { ActorVisual } from './ActorVisual';
import type { FigureAnimState } from './types';

export type { FigureAnimName, FigureAnimState } from './types';

export type PlayerFigureClassId = 'knight' | 'rogue' | 'mage';

export type EnemyFigureKind =
  | 'meleeKnightAdd'
  | 'necromancer'
  | 'skeletonMage'
  | 'rogueSkeleton'
  | 'skeletonGolem'
  | 'minionSkeleton';

export interface FigureColors {
  skin?: THREE.ColorRepresentation;
  cloth?: THREE.ColorRepresentation;
  armor?: THREE.ColorRepresentation;
  accent?: THREE.ColorRepresentation;
  bone?: THREE.ColorRepresentation;
  weapon?: THREE.ColorRepresentation;
  magic?: THREE.ColorRepresentation;
  ink?: THREE.ColorRepresentation;
  rim?: THREE.ColorRepresentation;
}

export interface FigureParts {
  body: THREE.Group;
  hips: THREE.Group;
  torso: THREE.Group;
  head: THREE.Group;
  leftArm: THREE.Group;
  rightArm: THREE.Group;
  leftForearm: THREE.Group;
  rightForearm: THREE.Group;
  leftLeg: THREE.Group;
  rightLeg: THREE.Group;
  leftShin: THREE.Group;
  rightShin: THREE.Group;
  weapon: THREE.Group;
  offhand: THREE.Group;
  meshes: THREE.Mesh[];
}

export interface ProceduralFigure extends ActorVisual {
  readonly parts: FigureParts;
}

/** One asymmetric silhouette element per archetype so facing is never ambiguous. */
type FigureFlair = 'none' | 'sash' | 'mantle';

/** Head-mounted silhouette breaker; separates staff users from each other. */
type FigureCrown = 'none' | 'antlers';

interface RigOptions {
  scale: number;
  stocky: number;
  headScale: number;
  weapon: 'sword' | 'daggers' | 'staff' | 'boneStaff' | 'bow' | 'club' | 'claws';
  skeleton: boolean;
  elite: boolean;
  hood: boolean;
  cape: boolean;
  shoulderPads: boolean;
  helmet: boolean;
  flair: FigureFlair;
  crown: FigureCrown;
}

interface DefaultPose {
  bodyY: number;
  torsoRotation: THREE.Euler;
  headRotation: THREE.Euler;
  leftArmRotation: THREE.Euler;
  rightArmRotation: THREE.Euler;
  leftForearmRotation: THREE.Euler;
  rightForearmRotation: THREE.Euler;
  leftLegRotation: THREE.Euler;
  rightLegRotation: THREE.Euler;
  leftShinRotation: THREE.Euler;
  rightShinRotation: THREE.Euler;
  weaponRotation: THREE.Euler;
  weaponPosition: THREE.Vector3;
}

const PLAYER_DEFAULTS: Record<PlayerFigureClassId, RigOptions> = {
  knight: {
    scale: 1.34,
    stocky: 1.22,
    headScale: 1,
    weapon: 'sword',
    skeleton: false,
    elite: false,
    hood: false,
    cape: true,
    shoulderPads: true,
    helmet: true,
    flair: 'none',
    crown: 'none',
  },
  rogue: {
    scale: 1.26,
    stocky: 1.0,
    headScale: 0.95,
    weapon: 'daggers',
    skeleton: false,
    elite: false,
    hood: true,
    cape: false,
    shoulderPads: false,
    helmet: false,
    flair: 'sash',
    crown: 'none',
  },
  mage: {
    scale: 1.28,
    stocky: 1.02,
    headScale: 1,
    weapon: 'staff',
    skeleton: false,
    elite: false,
    hood: true,
    cape: true,
    shoulderPads: false,
    helmet: false,
    flair: 'mantle',
    crown: 'none',
  },
};

const ENEMY_DEFAULTS: Record<EnemyFigureKind, RigOptions> = {
  meleeKnightAdd: {
    scale: 1.28,
    stocky: 1.18,
    headScale: 0.95,
    weapon: 'sword',
    skeleton: false,
    elite: false,
    hood: false,
    cape: false,
    shoulderPads: true,
    helmet: true,
    flair: 'none',
    crown: 'none',
  },
  necromancer: {
    scale: 1.26,
    stocky: 1,
    headScale: 1.05,
    weapon: 'boneStaff',
    skeleton: false,
    elite: false,
    hood: true,
    cape: true,
    shoulderPads: false,
    helmet: false,
    flair: 'mantle',
    crown: 'none',
  },
  skeletonMage: {
    scale: 1.2,
    stocky: 0.94,
    headScale: 1,
    weapon: 'boneStaff',
    skeleton: true,
    elite: false,
    hood: false,
    cape: false,
    shoulderPads: false,
    helmet: false,
    flair: 'none',
    // Antlers keep the bare-skull caster from reading as the hooded one.
    crown: 'antlers',
  },
  rogueSkeleton: {
    scale: 1.18,
    stocky: 0.9,
    headScale: 0.95,
    weapon: 'bow',
    skeleton: true,
    elite: false,
    hood: true,
    cape: false,
    shoulderPads: false,
    helmet: false,
    flair: 'sash',
    crown: 'none',
  },
  skeletonGolem: {
    scale: 1.6,
    stocky: 1.36,
    headScale: 1.12,
    weapon: 'club',
    skeleton: true,
    elite: true,
    hood: false,
    cape: false,
    shoulderPads: true,
    helmet: false,
    flair: 'none',
    crown: 'none',
  },
  minionSkeleton: {
    scale: 1.08,
    stocky: 0.9,
    headScale: 0.9,
    weapon: 'claws',
    skeleton: true,
    elite: false,
    hood: false,
    cape: false,
    shoulderPads: false,
    helmet: false,
    flair: 'none',
    crown: 'none',
  },
};

const BASE_COLORS: Required<FigureColors> = {
  skin: '#f0b47a',
  cloth: '#3a4a6e',
  armor: '#d8e0e6',
  accent: '#ffd766',
  bone: '#efe2c4',
  weapon: '#f0f5f8',
  magic: '#8ef2ff',
  ink: '#17131c',
  rim: '#fff0b8',
};

/**
 * Player identities. `cloth` is the primary garment mass, `armor` the plate
 * secondary, `skin`/`bone` the light flesh zone, `accent` the ~10% loud colour.
 */
const PLAYER_COLORS: Record<PlayerFigureClassId, FigureColors> = {
  knight: {
    skin: '#f0b980',
    cloth: '#2e3d5e',
    armor: '#f2ead6',
    accent: '#ffc94f',
    weapon: '#f6fbff',
    magic: '#ffeaa0',
    ink: '#1b1420',
    rim: '#fff3ba',
  },
  rogue: {
    skin: '#e0a06d',
    cloth: '#17252a',
    armor: '#2a9d8f',
    accent: '#7ff2de',
    weapon: '#e8fbff',
    magic: '#68ffe0',
    ink: '#0c1416',
    rim: '#c8fff4',
  },
  mage: {
    skin: '#efb884',
    cloth: '#3f2a6b',
    armor: '#cbb8f5',
    accent: '#ffd970',
    weapon: '#f1e8c8',
    magic: '#88f4ff',
    ink: '#150e22',
    rim: '#f5e8ff',
  },
};

/** Enemy identities. Tarnished/desaturated secondaries keep them off the player's ivory. */
const ENEMY_COLORS: Record<EnemyFigureKind, FigureColors> = {
  meleeKnightAdd: {
    skin: '#efb783',
    cloth: '#3c1722',
    armor: '#c9b490',
    accent: '#cf2b40',
    bone: '#f0e4c8',
    weapon: '#e8e2cc',
    magic: '#ff5b72',
    ink: '#170e12',
    rim: '#ffd0a8',
  },
  necromancer: {
    skin: '#d88a96',
    cloth: '#3b1030',
    armor: '#8a3355',
    accent: '#ff3d6b',
    bone: '#efe0bf',
    weapon: '#f0dfba',
    magic: '#ff5a7c',
    ink: '#120711',
    rim: '#ffd0d8',
  },
  skeletonMage: {
    cloth: '#243851',
    bone: '#f2e7cd',
    armor: '#f2e7cd',
    accent: '#f2662f',
    weapon: '#f1ddb8',
    magic: '#ff9b55',
    ink: '#141319',
    rim: '#ffe0bc',
  },
  rogueSkeleton: {
    cloth: '#1e2f3a',
    bone: '#f0e6cf',
    armor: '#f0e6cf',
    accent: '#d12f49',
    weapon: '#f0fbff',
    magic: '#b8fff5',
    ink: '#0e161d',
    rim: '#d8fff5',
  },
  skeletonGolem: {
    cloth: '#4a3c28',
    bone: '#efe0bd',
    armor: '#efe0bd',
    accent: '#d63d3d',
    weapon: '#c8b58c',
    magic: '#ff6b58',
    ink: '#150e0a',
    rim: '#ffe0a8',
  },
  minionSkeleton: {
    cloth: '#332c3d',
    bone: '#f0e5cb',
    armor: '#f0e5cb',
    accent: '#cf3547',
    weapon: '#ecdfc2',
    magic: '#ff6a78',
    ink: '#13121a',
    rim: '#ffe5c0',
  },
};

/**
 * Resolved four-zone palette. The zones exist so no single value can cover the
 * whole figure: a body painted in one flat colour is the mannequin read the
 * art bible bans, regardless of how good the lighting model is.
 */
interface ZonePalette {
  /** Largest garment mass — torso wrap, hips, thighs. */
  primary: string;
  primaryDark: string;
  /** Plate/armour secondary, a clear value step from primary. */
  secondary: string;
  secondaryDark: string;
  /** Skin or bone; the lightest large zone, always on head and hands. */
  flesh: string;
  bone: string;
  /** Smallest area, most saturated. */
  accent: string;
  /** Explicitly darker than the legs so the figure reads as grounded. */
  boot: string;
  hood: string;
  weapon: string;
  magic: string;
  ink: string;
  rim: string;
}

const WHITE = new THREE.Color('#ffffff');
const BLACK = new THREE.Color('#000000');

function luminance(c: THREE.Color): number {
  return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722;
}

function ensureLighter(target: THREE.Color, reference: THREE.Color, minDelta: number): THREE.Color {
  const out = target.clone();
  const floor = luminance(reference) + minDelta;
  for (let i = 0; i < 24 && luminance(out) < floor; i++) out.lerp(WHITE, 0.12);
  return out;
}

function ensureDarker(target: THREE.Color, reference: THREE.Color, minDelta: number): THREE.Color {
  const out = target.clone();
  const ceiling = luminance(reference) - minDelta;
  for (let i = 0; i < 24 && luminance(out) > ceiling; i++) out.lerp(BLACK, 0.12);
  return out;
}

function hex(c: THREE.Color): string {
  return `#${c.getHexString()}`;
}

/** Pulls a colour toward its own luminance, preserving value while killing chroma. */
function desaturate(c: THREE.Color, amount: number): THREE.Color {
  const l = luminance(c);
  return c.clone().lerp(new THREE.Color(l, l, l), amount);
}

/**
 * Builds the zone palette and enforces the two grounding rules from the art
 * bible programmatically rather than trusting each hand-authored palette:
 * the head must out-value the torso, and the feet must under-value the legs.
 */
function deriveZones(input: FigureColors, skeleton: boolean, fleshMute: number): ZonePalette {
  const c = { ...BASE_COLORS, ...input };
  const cloth = new THREE.Color(c.cloth);
  const bone = new THREE.Color(c.bone);
  const armor = new THREE.Color(skeleton ? c.bone : c.armor);
  // Enemy skin is muted: saturated flesh on a background actor pulls focus off
  // the player, who should own the warmest hue in the frame.
  const flesh = desaturate(new THREE.Color(skeleton ? c.bone : c.skin), fleshMute);
  const ink = new THREE.Color(c.ink);

  // Limb plate sits a full step below the chest plate, so arms and shins never
  // merge with the torso into one continuous flat mass.
  const secondaryDark = armor.clone().lerp(cloth, 0.42).multiplyScalar(0.86);
  const primaryDark = cloth.clone().multiplyScalar(0.72);

  let boot = cloth.clone().lerp(ink, 0.5);
  boot = ensureDarker(boot, cloth, 0.04);
  boot = ensureDarker(boot, secondaryDark, 0.04);

  const headFlesh = ensureLighter(flesh, cloth, 0.12);
  // A hood is the head silhouette, so it obeys the head rule too.
  const hood = ensureLighter(cloth.clone().lerp(WHITE, 0.2), cloth, 0.08);

  return {
    primary: hex(cloth),
    primaryDark: hex(primaryDark),
    secondary: hex(armor),
    secondaryDark: hex(secondaryDark),
    flesh: hex(headFlesh),
    bone: hex(bone),
    accent: `#${new THREE.Color(c.accent).getHexString()}`,
    boot: hex(boot),
    hood: hex(hood),
    weapon: `#${new THREE.Color(c.weapon).getHexString()}`,
    magic: `#${new THREE.Color(c.magic).getHexString()}`,
    ink: hex(ink),
    rim: `#${new THREE.Color(c.rim).getHexString()}`,
  };
}

/**
 * Outline weight by part role (art bible §3.2). Width states importance, so it
 * is assigned by what a part *is*, never by whatever number was convenient.
 */
type OutlineRole = 'core' | 'head' | 'limb' | 'plate' | 'prop' | 'detail' | 'hairline';

const OUTLINE_ROLE: Record<OutlineRole, number> = {
  core: 1.0,
  head: 0.9,
  limb: 0.72,
  plate: 0.6,
  prop: 0.44,
  detail: 0.24,
  hairline: 0.12,
};

/** Foreground actors carry the heaviest ink in the scene. */
const PLAYER_INK_WIDTH = 0.045;
const ENEMY_INK_WIDTH = 0.038;
const ELITE_INK_WIDTH = 0.043;

type InkFn = (role: OutlineRole) => number;

function makeInkFn(base: number, scale: number): InkFn {
  // Mild size coupling: a golem earns slightly heavier ink than a minion
  // without letting raw scale override the role hierarchy.
  const sizeK = 0.85 + scale * 0.12;
  return (role) => base * OUTLINE_ROLE[role] * sizeK;
}

/** Matte surfaces: cloth, flesh, bone. */
function makeMaterial(
  color: THREE.ColorRepresentation,
  rim: THREE.ColorRepresentation,
  fill: THREE.ColorRepresentation = '#c8d8e8',
): THREE.ShaderMaterial {
  return createCelMaterial({
    color,
    rimColor: rim,
    fillColor: fill,
    matcapMix: 0.05,
    specularBand: 0.9,
    specularStrength: 0.16,
    ambient: 0.5,
    rimStrength: 0.55,
  });
}

/** Plate and blade: banded specular plus a touch of fake environment. */
function makeMetalMaterial(
  color: THREE.ColorRepresentation,
  rim: THREE.ColorRepresentation,
  fill: THREE.ColorRepresentation = '#c8d8e8',
): THREE.ShaderMaterial {
  return createCelMaterial({
    color,
    rimColor: rim,
    fillColor: fill,
    matcapMix: 0.22,
    specularBand: 0.8,
    specularStrength: 0.45,
    ambient: 0.46,
    rimStrength: 0.7,
  });
}

function addOutlinedMesh(
  parent: THREE.Object3D,
  mesh: THREE.Mesh,
  ink: THREE.ColorRepresentation,
  outlineWidth: number,
  meshes: THREE.Mesh[],
): THREE.Mesh {
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  attachOutline(parent, mesh, ink, outlineWidth);
  meshes.push(mesh);
  return mesh;
}

function makeCapsule(
  radius: number,
  length: number,
  material: THREE.Material,
  radialSegments = 8,
): THREE.Mesh {
  return new THREE.Mesh(new THREE.CapsuleGeometry(radius, length, 4, radialSegments), material);
}

/**
 * Squeezes a mass toward its lower end. Uniform-width limbs and slab torsos are
 * the single biggest reason a procedural figure reads as a mannequin: a body
 * carries its bulk at the shoulder and the joint and narrows toward the waist
 * and the extremity, and that taper is most of what the silhouette is made of.
 */
function taperGeometry(geometry: THREE.BufferGeometry, bottomScale: number): void {
  geometry.computeBoundingBox();
  const box = geometry.boundingBox;
  if (!box) return;
  const minY = box.min.y;
  const spanY = Math.max(box.max.y - minY, 1e-5);
  const position = geometry.attributes.position as THREE.BufferAttribute;
  for (let i = 0; i < position.count; i++) {
    const t = (position.getY(i) - minY) / spanY;
    const k = bottomScale + (1 - bottomScale) * t;
    position.setX(i, position.getX(i) * k);
    position.setZ(i, position.getZ(i) * k);
  }
  position.needsUpdate = true;
  geometry.computeVertexNormals();
}

function makeBox(size: THREE.Vector3, material: THREE.Material): THREE.Mesh {
  return new THREE.Mesh(new THREE.BoxGeometry(size.x, size.y, size.z, 1, 1, 1), material);
}

function makeSphere(radius: number, material: THREE.Material, widthSegments = 16): THREE.Mesh {
  return new THREE.Mesh(new THREE.SphereGeometry(radius, widthSegments, 10), material);
}

/**
 * Limb group with a joint sphere at the pivot so the segment always reads as
 * attached to its parent mass, no matter how the animation rotates it.
 */
function makeLimb(
  root: THREE.Group,
  name: string,
  radius: number,
  length: number,
  material: THREE.Material,
  jointMaterial: THREE.Material,
  jointRadius: number,
  ink: THREE.ColorRepresentation,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
  taper = 0.72,
): THREE.Group {
  const limb = new THREE.Group();
  limb.name = name;
  const joint = makeSphere(jointRadius, jointMaterial, 12);
  joint.name = `${name}_joint`;
  addOutlinedMesh(limb, joint, ink, inkFn('detail'), meshes);
  const mesh = makeCapsule(radius, length, material, 8);
  mesh.name = `${name}_capsule`;
  // Tapered before the hull is built, so the outline follows the new silhouette.
  taperGeometry(mesh.geometry, taper);
  mesh.position.y = -length * 0.5;
  addOutlinedMesh(limb, mesh, ink, inkFn('limb'), meshes);
  root.add(limb);
  return limb;
}

function addCape(
  torso: THREE.Group,
  zones: ZonePalette,
  scale: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const capeMat = makeMaterial(zones.primaryDark, zones.rim);
  const cape = makeBox(new THREE.Vector3(0.6 * scale, 1.06 * scale, 0.09 * scale), capeMat);
  cape.name = 'cape_panel';
  cape.position.set(-0.22 * scale, -0.3 * scale, -0.18 * scale);
  cape.rotation.z = 0.16;
  addOutlinedMesh(torso, cape, zones.ink, inkFn('plate'), meshes);
  const capeTail = makeBox(new THREE.Vector3(0.44 * scale, 0.4 * scale, 0.085 * scale), capeMat);
  capeTail.name = 'cape_tail';
  capeTail.position.set(-0.42 * scale, -0.82 * scale, -0.18 * scale);
  capeTail.rotation.z = 0.34;
  addOutlinedMesh(torso, capeTail, zones.ink, inkFn('prop'), meshes);
}

/** Single-sided sash: the cheapest way to make facing unambiguous. */
function addSash(
  torso: THREE.Group,
  zones: ZonePalette,
  scale: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const sash = makeBox(new THREE.Vector3(0.16 * scale, 0.86 * scale, 0.5 * scale), makeMaterial(zones.accent, zones.rim));
  sash.name = 'shoulder_sash';
  sash.position.set(0.16 * scale, -0.02 * scale, 0);
  sash.rotation.z = 0.42;
  addOutlinedMesh(torso, sash, zones.ink, inkFn('prop'), meshes);
  const knot = makeSphere(0.09 * scale, makeMaterial(zones.accent, zones.rim), 10);
  knot.name = 'sash_knot';
  knot.position.set(0.06 * scale, -0.38 * scale, 0.22 * scale);
  addOutlinedMesh(torso, knot, zones.ink, inkFn('detail'), meshes);
}

/** Asymmetric half-mantle for casters. */
function addMantle(
  torso: THREE.Group,
  zones: ZonePalette,
  scale: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const mantleMat = makeMaterial(zones.secondary, zones.rim);
  const mantle = new THREE.Mesh(
    new THREE.CylinderGeometry(0.2 * scale, 0.46 * scale, 0.5 * scale, 8, 1, true),
    mantleMat,
  );
  mantle.name = 'half_mantle';
  mantle.position.set(-0.04 * scale, 0.26 * scale, -0.16 * scale);
  mantle.rotation.z = 0.2;
  mantle.scale.z = 0.8;
  addOutlinedMesh(torso, mantle, zones.ink, inkFn('plate'), meshes);
  const clasp = makeBox(new THREE.Vector3(0.14 * scale, 0.14 * scale, 0.14 * scale), makeMetalMaterial(zones.accent, zones.rim));
  clasp.name = 'mantle_clasp';
  clasp.position.set(0.12 * scale, 0.34 * scale, 0.2 * scale);
  clasp.rotation.z = Math.PI * 0.25;
  addOutlinedMesh(torso, clasp, zones.ink, inkFn('detail'), meshes);
}

function addShoulderPad(
  parent: THREE.Group,
  side: number,
  zones: ZonePalette,
  scale: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const pad = makeBox(
    new THREE.Vector3(0.32 * scale, 0.17 * scale, 0.4 * scale),
    makeMetalMaterial(zones.secondary, zones.rim),
  );
  pad.name = side < 0 ? 'left_shoulder_pad' : 'right_shoulder_pad';
  pad.position.set(0.01 * scale, 0.13 * scale, side * 0.03 * scale);
  pad.rotation.x = side * 0.1;
  addOutlinedMesh(parent, pad, zones.ink, inkFn('plate'), meshes);
  const trim = makeBox(
    new THREE.Vector3(0.34 * scale, 0.05 * scale, 0.42 * scale),
    makeMetalMaterial(zones.accent, zones.rim),
  );
  trim.name = `${pad.name}_trim`;
  trim.position.set(0.01 * scale, 0.045 * scale, side * 0.03 * scale);
  trim.rotation.x = side * 0.1;
  addOutlinedMesh(parent, trim, zones.ink, inkFn('detail'), meshes);
}

function addHelmet(
  head: THREE.Group,
  zones: ZonePalette,
  scale: number,
  headScale: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const armorMat = makeMetalMaterial(zones.secondary, zones.rim);
  const guardMat = makeMetalMaterial(zones.secondaryDark, zones.rim);
  const accentMat = makeMetalMaterial(zones.accent, zones.rim);
  const inkMat = makeMaterial(zones.ink, zones.rim);

  const dome = makeSphere(0.27 * headScale * scale, armorMat, 16);
  dome.name = 'helmet_dome';
  dome.position.set(-0.01 * scale, 0.03 * scale, 0);
  dome.scale.y = 1.08;
  addOutlinedMesh(head, dome, zones.ink, inkFn('head'), meshes);

  /**
   * The head is where the eye lands, so it carries four values of its own:
   * bright dome, darker brow and cheeks, an ink visor slot, and the accent
   * crest. A single-value dome reads as a lightbulb at gameplay distance.
   */
  const brow = makeBox(
    new THREE.Vector3(0.2 * scale, 0.09 * scale, 0.46 * headScale * scale),
    guardMat,
  );
  brow.name = 'helmet_brow_ridge';
  brow.position.set(0.16 * headScale * scale, 0.11 * scale, 0);
  brow.rotation.z = 0.12;
  addOutlinedMesh(head, brow, zones.ink, inkFn('detail'), meshes);

  const visor = makeBox(
    new THREE.Vector3(0.12 * scale, 0.1 * scale, 0.42 * headScale * scale),
    inkMat,
  );
  visor.name = 'helmet_visor_slit';
  visor.position.set(0.2 * headScale * scale, 0.005 * scale, 0);
  addOutlinedMesh(head, visor, zones.ink, inkFn('detail'), meshes);

  for (const side of [-1, 1]) {
    const cheek = makeBox(
      new THREE.Vector3(0.19 * scale, 0.22 * scale, 0.11 * scale),
      guardMat,
    );
    cheek.name = side < 0 ? 'helmet_cheek_left' : 'helmet_cheek_right';
    cheek.position.set(0.15 * headScale * scale, -0.13 * scale, side * 0.17 * headScale * scale);
    addOutlinedMesh(head, cheek, zones.ink, inkFn('detail'), meshes);
  }

  const crest = makeBox(new THREE.Vector3(0.42 * scale, 0.2 * scale, 0.05 * scale), accentMat);
  crest.name = 'helmet_crest_fin';
  crest.position.set(-0.02 * scale, 0.32 * scale, 0);
  crest.rotation.z = -0.08;
  addOutlinedMesh(head, crest, zones.ink, inkFn('detail'), meshes);
}

function addHood(
  head: THREE.Group,
  zones: ZonePalette,
  scale: number,
  headScale: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const clothMat = makeMaterial(zones.hood, zones.rim);
  const cowl = makeSphere(0.28 * headScale * scale, clothMat, 14);
  cowl.name = 'hood_cowl';
  cowl.position.set(-0.05 * scale, 0.05 * scale, 0);
  cowl.scale.set(1.04, 1.14, 1.08);
  addOutlinedMesh(head, cowl, zones.ink, inkFn('head'), meshes);

  const peak = new THREE.Mesh(new THREE.ConeGeometry(0.15 * scale, 0.34 * scale, 6), clothMat);
  peak.name = 'hood_peak';
  peak.position.set(-0.18 * scale, 0.26 * scale, 0);
  peak.rotation.z = 0.85;
  addOutlinedMesh(head, peak, zones.ink, inkFn('detail'), meshes);

  const drape = makeBox(new THREE.Vector3(0.16 * scale, 0.3 * scale, 0.36 * scale), clothMat);
  drape.name = 'hood_drape';
  drape.position.set(-0.16 * scale, -0.16 * scale, 0);
  drape.rotation.z = 0.14;
  addOutlinedMesh(head, drape, zones.ink, inkFn('detail'), meshes);
}

/** Tall bone antlers — the bare-skull caster's silhouette signature. */
function addAntlers(
  head: THREE.Group,
  zones: ZonePalette,
  scale: number,
  headScale: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const boneMat = makeMaterial(zones.bone, zones.rim);
  const emberMat = makeMaterial(zones.accent, zones.rim);
  for (const side of [-1, 1]) {
    const horn = new THREE.Mesh(new THREE.ConeGeometry(0.06 * scale, 0.62 * scale, 5), boneMat);
    horn.name = side < 0 ? 'antler_left' : 'antler_right';
    horn.position.set(-0.04 * scale, 0.42 * headScale * scale, side * 0.14 * scale);
    horn.rotation.x = side * 0.42;
    horn.rotation.z = 0.18;
    addOutlinedMesh(head, horn, zones.ink, inkFn('detail'), meshes);

    const branch = new THREE.Mesh(new THREE.ConeGeometry(0.035 * scale, 0.3 * scale, 4), boneMat);
    branch.name = `${horn.name}_branch`;
    branch.position.set(-0.1 * scale, 0.5 * headScale * scale, side * 0.24 * scale);
    branch.rotation.x = side * 0.85;
    addOutlinedMesh(head, branch, zones.ink, inkFn('hairline'), meshes);
  }
  const ember = makeSphere(0.07 * scale, emberMat, 10);
  ember.name = 'antler_ember';
  ember.position.set(-0.06 * scale, 0.66 * headScale * scale, 0);
  addOutlinedMesh(head, ember, zones.ink, inkFn('hairline'), meshes);
}

function addSkullDetail(
  head: THREE.Group,
  zones: ZonePalette,
  scale: number,
  headScale: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const boneMat = makeMaterial(zones.bone, zones.rim);
  const socketMat = makeMaterial(zones.ink, zones.accent);

  for (const side of [-1, 1]) {
    const socket = makeSphere(0.062 * headScale * scale, socketMat, 10);
    socket.name = side < 0 ? 'skull_socket_left' : 'skull_socket_right';
    socket.position.set(0.17 * headScale * scale, 0.03 * scale, side * 0.095 * headScale * scale);
    addOutlinedMesh(head, socket, zones.ink, inkFn('hairline'), meshes);
  }

  const nose = makeBox(new THREE.Vector3(0.05 * scale, 0.07 * scale, 0.045 * scale), socketMat);
  nose.name = 'skull_nose_slit';
  nose.position.set(0.2 * headScale * scale, -0.07 * scale, 0);
  addOutlinedMesh(head, nose, zones.ink, inkFn('hairline'), meshes);

  const jaw = makeBox(new THREE.Vector3(0.2 * headScale * scale, 0.1 * scale, 0.22 * headScale * scale), boneMat);
  jaw.name = 'skull_jaw';
  jaw.position.set(0.06 * headScale * scale, -0.21 * headScale * scale, 0);
  addOutlinedMesh(head, jaw, zones.ink, inkFn('detail'), meshes);
}

function addRibcage(
  torso: THREE.Group,
  zones: ZonePalette,
  scale: number,
  stocky: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const boneMat = makeMaterial(zones.bone, zones.rim);
  for (let i = 0; i < 3; i++) {
    const rib = makeBox(
      new THREE.Vector3(0.64 * stocky * scale, 0.055 * scale, 0.47 * scale),
      boneMat,
    );
    rib.name = `rib_band_${i}`;
    rib.position.y = (0.22 - i * 0.17) * scale;
    addOutlinedMesh(torso, rib, zones.ink, inkFn('hairline'), meshes);
  }
  const spine = makeBox(new THREE.Vector3(0.1 * scale, 0.66 * scale, 0.09 * scale), boneMat);
  spine.name = 'spine_column';
  spine.position.set(-0.24 * stocky * scale, -0.02 * scale, 0);
  addOutlinedMesh(torso, spine, zones.ink, inkFn('hairline'), meshes);
}

function buildWeapon(
  weaponRoot: THREE.Group,
  options: RigOptions,
  zones: ZonePalette,
  scale: number,
  inkFn: InkFn,
  meshes: THREE.Mesh[],
): void {
  const weaponMat = makeMetalMaterial(zones.weapon, zones.rim);
  const accentMat = makeMetalMaterial(zones.accent, zones.rim);
  const boneMat = makeMaterial(zones.bone, zones.rim);
  const magicMat = makeMaterial(zones.magic, zones.rim);

  if (options.weapon === 'sword') {
    const blade = makeBox(new THREE.Vector3(0.14 * scale, 0.98 * scale, 0.08 * scale), weaponMat);
    blade.name = 'sword_blade';
    blade.position.y = -0.52 * scale;
    addOutlinedMesh(weaponRoot, blade, zones.ink, inkFn('prop'), meshes);
    const guard = makeBox(new THREE.Vector3(0.48 * scale, 0.1 * scale, 0.11 * scale), accentMat);
    guard.name = 'sword_guard';
    guard.position.y = -0.08 * scale;
    addOutlinedMesh(weaponRoot, guard, zones.ink, inkFn('detail'), meshes);
    const pommel = makeSphere(0.07 * scale, accentMat, 10);
    pommel.name = 'sword_pommel';
    pommel.position.y = 0.1 * scale;
    addOutlinedMesh(weaponRoot, pommel, zones.ink, inkFn('hairline'), meshes);
  } else if (options.weapon === 'daggers') {
    for (const side of [-1, 1]) {
      const dagger = makeBox(new THREE.Vector3(0.08 * scale, 0.48 * scale, 0.06 * scale), weaponMat);
      dagger.name = side < 0 ? 'left_dagger' : 'right_dagger';
      dagger.position.set(side * 0.07 * scale, -0.3 * scale, side * 0.03 * scale);
      dagger.rotation.z = side * 0.3;
      addOutlinedMesh(weaponRoot, dagger, zones.ink, inkFn('detail'), meshes);
    }
  } else if (options.weapon === 'staff' || options.weapon === 'boneStaff') {
    const staffMat = options.weapon === 'boneStaff' ? boneMat : weaponMat;
    const shaft = makeCapsule(0.05 * scale, 1.42 * scale, staffMat, 8);
    shaft.name = 'staff_shaft';
    shaft.position.y = -0.54 * scale;
    addOutlinedMesh(weaponRoot, shaft, zones.ink, inkFn('detail'), meshes);
    const orb = makeSphere(0.19 * scale, magicMat, 12);
    orb.name = 'staff_focus';
    orb.position.y = 0.2 * scale;
    addOutlinedMesh(weaponRoot, orb, zones.ink, inkFn('prop'), meshes);
  } else if (options.weapon === 'bow') {
    const bow = new THREE.Mesh(new THREE.TorusGeometry(0.4 * scale, 0.036 * scale, 6, 18, Math.PI * 1.35), weaponMat);
    bow.name = 'bow_arc';
    bow.rotation.z = Math.PI * 0.5;
    bow.position.y = -0.3 * scale;
    addOutlinedMesh(weaponRoot, bow, zones.ink, inkFn('detail'), meshes);
    const string = makeBox(new THREE.Vector3(0.03 * scale, 0.76 * scale, 0.03 * scale), accentMat);
    string.name = 'bow_string_block';
    string.position.y = -0.3 * scale;
    addOutlinedMesh(weaponRoot, string, zones.ink, inkFn('hairline'), meshes);
  } else if (options.weapon === 'club') {
    const club = makeCapsule(0.1 * scale, 0.84 * scale, weaponMat, 10);
    club.name = 'golem_club';
    club.position.y = -0.48 * scale;
    club.scale.x = 1.55;
    club.scale.z = 1.2;
    addOutlinedMesh(weaponRoot, club, zones.ink, inkFn('prop'), meshes);
  } else {
    const claw = makeBox(new THREE.Vector3(0.1 * scale, 0.4 * scale, 0.07 * scale), weaponMat);
    claw.name = 'bone_claw';
    claw.position.y = -0.24 * scale;
    claw.rotation.z = -0.45;
    addOutlinedMesh(weaponRoot, claw, zones.ink, inkFn('detail'), meshes);
  }
}

function createDefaultPose(parts: FigureParts): DefaultPose {
  return {
    bodyY: parts.body.position.y,
    torsoRotation: parts.torso.rotation.clone(),
    headRotation: parts.head.rotation.clone(),
    leftArmRotation: parts.leftArm.rotation.clone(),
    rightArmRotation: parts.rightArm.rotation.clone(),
    leftForearmRotation: parts.leftForearm.rotation.clone(),
    rightForearmRotation: parts.rightForearm.rotation.clone(),
    leftLegRotation: parts.leftLeg.rotation.clone(),
    rightLegRotation: parts.rightLeg.rotation.clone(),
    leftShinRotation: parts.leftShin.rotation.clone(),
    rightShinRotation: parts.rightShin.rotation.clone(),
    weaponRotation: parts.weapon.rotation.clone(),
    weaponPosition: parts.weapon.position.clone(),
  };
}

function resetPose(parts: FigureParts, pose: DefaultPose): void {
  parts.body.position.y = pose.bodyY;
  parts.torso.rotation.copy(pose.torsoRotation);
  parts.head.rotation.copy(pose.headRotation);
  parts.leftArm.rotation.copy(pose.leftArmRotation);
  parts.rightArm.rotation.copy(pose.rightArmRotation);
  parts.leftForearm.rotation.copy(pose.leftForearmRotation);
  parts.rightForearm.rotation.copy(pose.rightForearmRotation);
  parts.leftLeg.rotation.copy(pose.leftLegRotation);
  parts.rightLeg.rotation.copy(pose.rightLegRotation);
  parts.leftShin.rotation.copy(pose.leftShinRotation);
  parts.rightShin.rotation.copy(pose.rightShinRotation);
  parts.weapon.rotation.copy(pose.weaponRotation);
  parts.weapon.position.copy(pose.weaponPosition);
}

function applyIdle(parts: FigureParts, time: number, intensity: number): void {
  const breath = Math.sin(time * 3.2) * intensity;
  // Slow weight-shift layered under the breath so still frames never read as a T-pose.
  const sway = Math.sin(time * 1.15 + 0.6) * intensity;
  parts.body.position.y += breath * 0.035;
  parts.torso.rotation.z += breath * 0.025 + 0.035 * intensity + sway * 0.015;
  parts.torso.rotation.x += sway * 0.02;
  parts.head.rotation.z -= breath * 0.018 + 0.055 * intensity;
  parts.head.rotation.x += sway * 0.04;
  parts.leftArm.rotation.z += 0.08 + breath * 0.06 + sway * 0.025;
  parts.rightArm.rotation.z -= 0.08 + breath * 0.05 - sway * 0.015;
  parts.rightForearm.rotation.z -= 0.07 * intensity;
  // Weight on the left leg, right leg eased with a soft knee bend.
  parts.leftLeg.rotation.z += 0.045 * intensity + sway * 0.012;
  parts.rightLeg.rotation.z -= 0.065 * intensity;
  parts.rightShin.rotation.z += 0.055 * intensity;
  // Weapon held ready, drifting with the sway instead of hanging frozen.
  parts.weapon.rotation.z -= 0.14 * intensity + sway * 0.035;
}

function applyWalk(parts: FigureParts, time: number, speed: number, intensity: number): void {
  const stride = Math.sin(time * Math.max(speed, 0.2) * 8.2);
  const counter = Math.cos(time * Math.max(speed, 0.2) * 8.2);
  const swing = 0.58 * intensity;
  parts.body.position.y += Math.abs(counter) * 0.035;
  parts.leftLeg.rotation.z += stride * swing;
  parts.rightLeg.rotation.z -= stride * swing;
  parts.leftShin.rotation.z -= Math.max(0, -stride) * 0.55 * intensity;
  parts.rightShin.rotation.z -= Math.max(0, stride) * 0.55 * intensity;
  parts.leftArm.rotation.z -= stride * 0.44 * intensity;
  parts.rightArm.rotation.z += stride * 0.44 * intensity;
  parts.torso.rotation.z += stride * 0.045 * intensity;
}

function applyAttack(parts: FigureParts, attackT: number, intensity: number): void {
  const t = THREE.MathUtils.clamp(attackT, 0, 1);
  const wind = Math.sin(Math.min(t * 2, 1) * Math.PI * 0.5);
  const strike = Math.sin(THREE.MathUtils.clamp((t - 0.22) / 0.45, 0, 1) * Math.PI);
  parts.torso.rotation.z -= strike * 0.2 * intensity;
  parts.rightArm.rotation.z = -0.85 + wind * 1.0 - strike * 1.7 * intensity;
  parts.rightForearm.rotation.z = -0.35 - strike * 0.5 * intensity;
  parts.weapon.rotation.z = -0.2 - strike * 1.2 * intensity;
  parts.weapon.position.x += strike * 0.18 * intensity;
  parts.leftArm.rotation.z += strike * 0.35 * intensity;
}

function applyCast(parts: FigureParts, time: number, attackT: number, intensity: number): void {
  const pulse = Math.sin(time * 12) * 0.05 * intensity;
  const raise = Math.sin(THREE.MathUtils.clamp(attackT, 0, 1) * Math.PI);
  parts.rightArm.rotation.z = -1.65 + pulse;
  parts.rightForearm.rotation.z = -0.25 - raise * 0.25;
  parts.leftArm.rotation.z = 1.15 - pulse;
  parts.head.rotation.z += pulse * 0.7;
  parts.weapon.position.y += raise * 0.12;
}

function applyDeath(parts: FigureParts, deathT: number): void {
  const t = THREE.MathUtils.clamp(deathT, 0, 1);
  const slump = 1 - Math.pow(1 - t, 3);
  parts.body.position.y -= slump * 0.58;
  parts.body.rotation.z = -slump * 1.14;
  parts.torso.rotation.x = slump * 0.42;
  parts.head.rotation.z = slump * 0.72;
  parts.leftLeg.rotation.z = -0.72 * slump;
  parts.rightLeg.rotation.z = 0.38 * slump;
  parts.leftArm.rotation.z = 1.2 * slump;
  parts.rightArm.rotation.z = -1.05 * slump;
  parts.weapon.rotation.z = -0.9 * slump;
}

function buildFigure(
  options: RigOptions,
  colorsInput: FigureColors,
  label: string,
  inkBase: number,
  fleshMute: number,
): ProceduralFigure {
  const z = deriveZones(colorsInput, options.skeleton, fleshMute);
  const root = new THREE.Group();
  root.name = `${label}_figure_root`;
  const partsMeshes: THREE.Mesh[] = [];
  const scale = options.scale;
  const stocky = options.stocky;
  const inkFn = makeInkFn(inkBase, scale);
  const body = new THREE.Group();
  body.name = 'figure_body';
  body.position.y = 0;
  root.add(body);

  // Zone materials. The split matters more than any single colour: the largest
  // mass, the plate, the flesh, and the accent must all differ in value.
  const primaryMat = makeMaterial(z.primary, z.rim);
  const primaryDarkMat = makeMaterial(z.primaryDark, z.rim);
  const secondaryMat = makeMetalMaterial(z.secondary, z.rim);
  const secondaryDarkMat = makeMetalMaterial(z.secondaryDark, z.rim);
  const fleshMat = makeMaterial(z.flesh, z.rim);
  const boneMat = makeMaterial(z.bone, z.rim);
  const accentMat = makeMetalMaterial(z.accent, z.rim);
  const bootMat = makeMaterial(z.boot, z.rim);

  // --- Pelvis / hip mass: block + downward wedge bridging torso to legs ---
  const hips = new THREE.Group();
  hips.name = 'hips';
  hips.position.y = 1.06 * scale;
  body.add(hips);
  const hipMesh = makeBox(
    new THREE.Vector3(0.5 * stocky * scale, 0.28 * scale, 0.44 * scale),
    primaryMat,
  );
  hipMesh.name = 'hips_block';
  addOutlinedMesh(hips, hipMesh, z.ink, inkFn('limb'), partsMeshes);

  const pelvisWedge = new THREE.Mesh(
    new THREE.ConeGeometry(0.29 * stocky * scale, 0.34 * scale, 4),
    primaryDarkMat,
  );
  pelvisWedge.name = 'pelvis_wedge';
  pelvisWedge.rotation.x = Math.PI;
  pelvisWedge.rotation.y = Math.PI * 0.25;
  pelvisWedge.position.y = -0.2 * scale;
  addOutlinedMesh(hips, pelvisWedge, z.ink, inkFn('plate'), partsMeshes);

  const belt = makeBox(new THREE.Vector3(0.54 * stocky * scale, 0.11 * scale, 0.47 * scale), accentMat);
  belt.name = 'belt_band';
  belt.position.y = 0.17 * scale;
  addOutlinedMesh(hips, belt, z.ink, inkFn('detail'), partsMeshes);

  // --- Torso: garment core, then a plate on top so the chest is never one value ---
  const torso = new THREE.Group();
  torso.name = 'torso';
  torso.position.y = 1.46 * scale;
  body.add(torso);
  const torsoMesh = makeBox(
    new THREE.Vector3(0.62 * stocky * scale, 0.72 * scale, 0.44 * scale),
    primaryMat,
  );
  torsoMesh.name = 'torso_block';
  torsoMesh.rotation.z = -0.04;
  // Chest wider than waist. A straight slab torso is a mannequin torso however
  // well it is coloured, and the V is what the eye reads as a body.
  taperGeometry(torsoMesh.geometry, 0.76);
  addOutlinedMesh(torso, torsoMesh, z.ink, inkFn('core'), partsMeshes);

  if (options.skeleton) {
    addRibcage(torso, z, scale, stocky, inkFn, partsMeshes);
  } else {
    const chestPlate = makeBox(
      new THREE.Vector3(0.7 * stocky * scale, 0.42 * scale, 0.5 * scale),
      secondaryMat,
    );
    chestPlate.name = 'chest_plate';
    chestPlate.position.y = 0.15 * scale;
    chestPlate.rotation.z = -0.06;
    taperGeometry(chestPlate.geometry, 0.7);
    addOutlinedMesh(torso, chestPlate, z.ink, inkFn('plate'), partsMeshes);

    const chestTrim = makeBox(
      new THREE.Vector3(0.72 * stocky * scale, 0.08 * scale, 0.52 * scale),
      accentMat,
    );
    chestTrim.name = 'chest_plate_bevel';
    chestTrim.position.y = -0.08 * scale;
    chestTrim.rotation.z = -0.06;
    addOutlinedMesh(torso, chestTrim, z.ink, inkFn('detail'), partsMeshes);

    const collar = new THREE.Mesh(
      new THREE.CylinderGeometry(0.16 * scale, 0.21 * scale, 0.12 * scale, 8),
      accentMat,
    );
    collar.name = 'collar_ring';
    collar.position.y = 0.4 * scale;
    addOutlinedMesh(torso, collar, z.ink, inkFn('detail'), partsMeshes);
  }

  if (options.cape) addCape(torso, z, scale, inkFn, partsMeshes);
  if (options.flair === 'sash') addSash(torso, z, scale, inkFn, partsMeshes);
  else if (options.flair === 'mantle') addMantle(torso, z, scale, inkFn, partsMeshes);

  // --- Neck bridging torso top to head ---
  const neck = makeCapsule(0.085 * scale, 0.15 * scale, fleshMat, 8);
  neck.name = 'neck_column';
  neck.position.y = 1.9 * scale;
  addOutlinedMesh(body, neck, z.ink, inkFn('detail'), partsMeshes);

  // --- Head: always the lightest large zone, so the eye lands on the face ---
  const head = new THREE.Group();
  head.name = 'head';
  head.position.y = 2.08 * scale;
  body.add(head);
  const headMesh = makeSphere(0.24 * options.headScale * scale, options.skeleton ? boneMat : fleshMat, options.skeleton ? 12 : 16);
  headMesh.name = 'head_sphere';
  headMesh.scale.y = options.skeleton ? 1.1 : 1;
  addOutlinedMesh(head, headMesh, z.ink, inkFn('head'), partsMeshes);

  if (options.skeleton) addSkullDetail(head, z, scale, options.headScale, inkFn, partsMeshes);
  if (options.helmet) addHelmet(head, z, scale, options.headScale, inkFn, partsMeshes);
  else if (options.hood) addHood(head, z, scale, options.headScale, inkFn, partsMeshes);
  if (options.crown === 'antlers') addAntlers(head, z, scale, options.headScale, inkFn, partsMeshes);

  // --- Arms: plate upper, flesh forearm, so limbs read in two values ---
  const shoulderY = 1.78 * scale;
  const shoulderZ = 0.27 * scale;
  const leftArm = makeLimb(
    body, 'left_upper_arm', 0.105 * scale, 0.44 * scale,
    secondaryMat, secondaryDarkMat, 0.14 * scale, z.ink, inkFn, partsMeshes,
  );
  const rightArm = makeLimb(
    body, 'right_upper_arm', 0.105 * scale, 0.44 * scale,
    secondaryMat, secondaryDarkMat, 0.14 * scale, z.ink, inkFn, partsMeshes,
  );
  leftArm.position.set(0, shoulderY, -shoulderZ);
  rightArm.position.set(0, shoulderY, shoulderZ);
  leftArm.rotation.z = 0.32;
  rightArm.rotation.z = -0.44;

  const leftForearm = makeLimb(
    leftArm, 'left_forearm', 0.09 * scale, 0.38 * scale,
    fleshMat, secondaryDarkMat, 0.105 * scale, z.ink, inkFn, partsMeshes,
  );
  const rightForearm = makeLimb(
    rightArm, 'right_forearm', 0.09 * scale, 0.38 * scale,
    fleshMat, secondaryDarkMat, 0.105 * scale, z.ink, inkFn, partsMeshes,
  );
  leftForearm.position.y = -0.48 * scale;
  rightForearm.position.y = -0.48 * scale;
  leftForearm.rotation.z = -0.28;
  rightForearm.rotation.z = -0.15;

  for (const [forearm, sideName] of [[leftForearm, 'left'], [rightForearm, 'right']] as const) {
    const fist = makeSphere(0.12 * scale, fleshMat, 12);
    fist.name = `${sideName}_fist`;
    fist.position.y = -0.5 * scale;
    fist.scale.set(1.05, 0.95, 1);
    addOutlinedMesh(forearm, fist, z.ink, inkFn('detail'), partsMeshes);
  }

  if (options.shoulderPads) {
    addShoulderPad(leftArm, -1, z, scale, inkFn, partsMeshes);
    addShoulderPad(rightArm, 1, z, scale, inkFn, partsMeshes);
  }

  // --- Legs: garment thigh, darker greave, darkest boot. Reads as grounded. ---
  const legY = 1.0 * scale;
  const legZ = 0.18 * scale;
  const leftLeg = makeLimb(
    body, 'left_thigh', 0.125 * scale, 0.42 * scale,
    primaryMat, primaryDarkMat, 0.145 * scale, z.ink, inkFn, partsMeshes, 0.8,
  );
  const rightLeg = makeLimb(
    body, 'right_thigh', 0.125 * scale, 0.42 * scale,
    primaryMat, primaryDarkMat, 0.145 * scale, z.ink, inkFn, partsMeshes, 0.8,
  );
  leftLeg.position.set(0, legY, -legZ);
  rightLeg.position.set(0, legY, legZ);
  leftLeg.rotation.z = 0.08;
  rightLeg.rotation.z = -0.08;

  const leftShin = makeLimb(
    leftLeg, 'left_shin', 0.1 * scale, 0.34 * scale,
    secondaryDarkMat, primaryDarkMat, 0.115 * scale, z.ink, inkFn, partsMeshes,
  );
  const rightShin = makeLimb(
    rightLeg, 'right_shin', 0.1 * scale, 0.34 * scale,
    secondaryDarkMat, primaryDarkMat, 0.115 * scale, z.ink, inkFn, partsMeshes,
  );
  leftShin.position.y = -0.5 * scale;
  rightShin.position.y = -0.5 * scale;
  leftShin.rotation.z = -0.12;
  rightShin.rotation.z = 0.12;

  for (const shin of [leftShin, rightShin]) {
    const boot = makeBox(new THREE.Vector3(0.36 * scale, 0.17 * scale, 0.21 * scale), bootMat);
    boot.name = `${shin.name}_foot`;
    boot.position.set(0.1 * scale, -0.42 * scale, 0);
    addOutlinedMesh(shin, boot, z.ink, inkFn('limb'), partsMeshes);
  }

  // --- Weapon / offhand anchored to wrists ---
  const weapon = new THREE.Group();
  weapon.name = 'weapon';
  weapon.position.set(0.11 * scale, -0.48 * scale, 0.02 * scale);
  weapon.rotation.z = options.weapon === 'bow' ? -0.55 : -0.22;
  rightForearm.add(weapon);
  buildWeapon(weapon, options, z, scale, inkFn, partsMeshes);

  const offhand = new THREE.Group();
  offhand.name = 'offhand';
  offhand.position.set(0.08 * scale, -0.46 * scale, -0.01 * scale);
  leftForearm.add(offhand);
  if (options.weapon === 'sword' && !options.skeleton) {
    const shield = makeBox(new THREE.Vector3(0.17 * scale, 0.56 * scale, 0.5 * scale), secondaryMat);
    shield.name = 'kite_shield';
    shield.rotation.z = 0.1;
    addOutlinedMesh(offhand, shield, z.ink, inkFn('plate'), partsMeshes);
    const shieldBoss = makeSphere(0.09 * scale, accentMat, 10);
    shieldBoss.name = 'kite_shield_boss';
    shieldBoss.position.x = 0.1 * scale;
    addOutlinedMesh(offhand, shieldBoss, z.ink, inkFn('detail'), partsMeshes);
  }

  if (options.elite) {
    const crest = new THREE.Mesh(new THREE.ConeGeometry(0.18 * scale, 0.34 * scale, 4), accentMat);
    crest.name = 'elite_crest';
    crest.position.y = 0.28 * scale;
    crest.rotation.y = Math.PI * 0.25;
    addOutlinedMesh(head, crest, z.ink, inkFn('detail'), partsMeshes);
  }

  const parts: FigureParts = {
    body,
    hips,
    torso,
    head,
    leftArm,
    rightArm,
    leftForearm,
    rightForearm,
    leftLeg,
    rightLeg,
    leftShin,
    rightShin,
    weapon,
    offhand,
    meshes: partsMeshes,
  };
  const defaultPose = createDefaultPose(parts);
  let facing = 1;
  let animTime = 0;

  const setFacing = (dir: number): void => {
    const nextFacing = dir < 0 ? -1 : 1;
    if (nextFacing === facing) return;
    facing = nextFacing;
    root.rotation.y = facing < 0 ? Math.PI : 0;
  };

  const updateAnim = (dt: number, state: FigureAnimState): void => {
    animTime += dt;
    resetPose(parts, defaultPose);
    const intensity = state.intensity ?? 1;
    if (state.name === 'walk') {
      applyWalk(parts, animTime, state.speed ?? 1, intensity);
    } else if (state.name === 'attack') {
      applyIdle(parts, animTime, 0.35 * intensity);
      applyAttack(parts, state.attackT ?? 0, intensity);
    } else if (state.name === 'cast') {
      applyIdle(parts, animTime, 0.25 * intensity);
      applyCast(parts, animTime, state.attackT ?? 0, intensity);
    } else if (state.name === 'hurt') {
      parts.body.position.y += Math.sin(animTime * 45) * 0.015 * intensity;
      parts.torso.rotation.z -= 0.22 * intensity;
      parts.head.rotation.z += 0.28 * intensity;
    } else if (state.name === 'death') {
      applyDeath(parts, state.deathT ?? 1);
    } else {
      applyIdle(parts, animTime, intensity);
    }
  };

  const dispose = (): void => {
    const geometries = new Set<THREE.BufferGeometry>();
    const materials = new Set<THREE.Material>();
    root.traverse((object) => {
      if (!(object instanceof THREE.Mesh)) return;
      geometries.add(object.geometry);
      const meshMaterials = Array.isArray(object.material) ? object.material : [object.material];
      for (const material of meshMaterials) materials.add(material);
    });
    for (const geometry of geometries) geometry.dispose();
    for (const material of materials) material.dispose();
    root.clear();
  };

  return { root, parts, setFacing, updateAnim, dispose };
}

/** Enemies give up chroma in the flesh zone so the player keeps the warmest skin on screen. */
const ENEMY_FLESH_MUTE = 0.42;

export function buildPlayerFigure(classId: PlayerFigureClassId, colors: FigureColors = {}): ProceduralFigure {
  return buildFigure(
    PLAYER_DEFAULTS[classId],
    { ...PLAYER_COLORS[classId], ...colors },
    `player_${classId}`,
    PLAYER_INK_WIDTH,
    0,
  );
}

export function buildEnemyFigure(kind: EnemyFigureKind, colors: FigureColors = {}): ProceduralFigure {
  const options = ENEMY_DEFAULTS[kind];
  return buildFigure(
    options,
    { ...ENEMY_COLORS[kind], ...colors },
    `enemy_${kind}`,
    options.elite ? ELITE_INK_WIDTH : ENEMY_INK_WIDTH,
    ENEMY_FLESH_MUTE,
  );
}
