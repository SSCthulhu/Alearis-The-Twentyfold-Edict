import * as THREE from 'three';
import { attachOutline, createCelMaterial } from '../render/CelMaterial';

export type PlayerFigureClassId = 'knight' | 'rogue' | 'mage';

export type EnemyFigureKind =
  | 'meleeKnightAdd'
  | 'necromancer'
  | 'skeletonMage'
  | 'rogueSkeleton'
  | 'skeletonGolem'
  | 'minionSkeleton';

export type FigureAnimName = 'idle' | 'walk' | 'attack' | 'cast' | 'hurt' | 'death';

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

export interface FigureAnimState {
  name: FigureAnimName;
  speed?: number;
  attackT?: number;
  deathT?: number;
  intensity?: number;
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

export interface ProceduralFigure {
  root: THREE.Group;
  parts: FigureParts;
  setFacing: (dir: number) => void;
  updateAnim: (dt: number, state: FigureAnimState) => void;
}

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
    scale: 1.24,
    stocky: 1.2,
    headScale: 1,
    weapon: 'sword',
    skeleton: false,
    elite: false,
    hood: false,
    cape: true,
    shoulderPads: true,
  },
  rogue: {
    scale: 1.18,
    stocky: 1.02,
    headScale: 0.95,
    weapon: 'daggers',
    skeleton: false,
    elite: false,
    hood: true,
    cape: false,
    shoulderPads: false,
  },
  mage: {
    scale: 1.2,
    stocky: 1.04,
    headScale: 1,
    weapon: 'staff',
    skeleton: false,
    elite: false,
    hood: true,
    cape: true,
    shoulderPads: false,
  },
};

const ENEMY_DEFAULTS: Record<EnemyFigureKind, RigOptions> = {
  meleeKnightAdd: {
    scale: 1.2,
    stocky: 1.18,
    headScale: 0.95,
    weapon: 'sword',
    skeleton: false,
    elite: false,
    hood: false,
    cape: false,
    shoulderPads: true,
  },
  necromancer: {
    scale: 1.18,
    stocky: 1,
    headScale: 1.05,
    weapon: 'boneStaff',
    skeleton: false,
    elite: false,
    hood: true,
    cape: true,
    shoulderPads: false,
  },
  skeletonMage: {
    scale: 1.12,
    stocky: 0.94,
    headScale: 1,
    weapon: 'boneStaff',
    skeleton: true,
    elite: false,
    hood: false,
    cape: false,
    shoulderPads: false,
  },
  rogueSkeleton: {
    scale: 1.1,
    stocky: 0.9,
    headScale: 0.95,
    weapon: 'bow',
    skeleton: true,
    elite: false,
    hood: true,
    cape: false,
    shoulderPads: false,
  },
  skeletonGolem: {
    scale: 1.5,
    stocky: 1.32,
    headScale: 1.12,
    weapon: 'club',
    skeleton: true,
    elite: true,
    hood: false,
    cape: false,
    shoulderPads: true,
  },
  minionSkeleton: {
    scale: 1.0,
    stocky: 0.9,
    headScale: 0.9,
    weapon: 'claws',
    skeleton: true,
    elite: false,
    hood: false,
    cape: false,
    shoulderPads: false,
  },
};

const BASE_COLORS: Required<FigureColors> = {
  skin: '#f0b47a',
  cloth: '#4a5f88',
  armor: '#d8e0e6',
  accent: '#ffd766',
  bone: '#efe2c4',
  weapon: '#f0f5f8',
  magic: '#8ef2ff',
  ink: '#17131c',
  rim: '#fff0b8',
};

const PLAYER_COLORS: Record<PlayerFigureClassId, FigureColors> = {
  knight: {
    skin: '#f0b980',
    cloth: '#efe7d4',
    armor: '#f5e4a8',
    accent: '#ffd45f',
    weapon: '#f6fbff',
    magic: '#fff0a8',
    ink: '#241812',
    rim: '#fff3ba',
  },
  rogue: {
    skin: '#e0a06d',
    cloth: '#20333a',
    armor: '#2cc7b8',
    accent: '#80f0df',
    weapon: '#e8fbff',
    magic: '#68ffe0',
    ink: '#10191b',
    rim: '#c8fff4',
  },
  mage: {
    skin: '#efb884',
    cloth: '#4f347c',
    armor: '#d4c7ff',
    accent: '#ffe080',
    weapon: '#f1e8c8',
    magic: '#88f4ff',
    ink: '#181026',
    rim: '#f5e8ff',
  },
};

const ENEMY_COLORS: Record<EnemyFigureKind, FigureColors> = {
  meleeKnightAdd: {
    skin: '#efb783',
    cloth: '#4b2130',
    armor: '#e4d6ba',
    accent: '#d94054',
    bone: '#f0e4c8',
    weapon: '#f3f0dc',
    magic: '#ff5b72',
    ink: '#1a1013',
    rim: '#ffd0a8',
  },
  necromancer: {
    skin: '#d88a96',
    cloth: '#4c1534',
    armor: '#8c3854',
    accent: '#ff3f62',
    bone: '#efe0bf',
    weapon: '#f0dfba',
    magic: '#ff5a7c',
    ink: '#140812',
    rim: '#ffd0d8',
  },
  skeletonMage: {
    cloth: '#304d6f',
    bone: '#efe3c7',
    armor: '#f0e3c6',
    accent: '#ff5f48',
    weapon: '#f1ddb8',
    magic: '#ff9b55',
    ink: '#15141a',
    rim: '#ffe0bc',
  },
  rogueSkeleton: {
    cloth: '#263846',
    bone: '#f0e6cf',
    armor: '#dbe8e8',
    accent: '#2fd0c8',
    weapon: '#f0fbff',
    magic: '#b8fff5',
    ink: '#101820',
    rim: '#d8fff5',
  },
  skeletonGolem: {
    cloth: '#5a4a37',
    bone: '#efe0bd',
    armor: '#c1ab81',
    accent: '#d63d3d',
    weapon: '#c8b58c',
    magic: '#ff6b58',
    ink: '#17100b',
    rim: '#ffe0a8',
  },
  minionSkeleton: {
    cloth: '#40394a',
    bone: '#f0e5cb',
    armor: '#eee0c0',
    accent: '#cf3547',
    weapon: '#ecdfc2',
    magic: '#ff6a78',
    ink: '#15141a',
    rim: '#ffe5c0',
  },
};

function mergeColors(colors: FigureColors): Required<FigureColors> {
  return { ...BASE_COLORS, ...colors };
}

function makeMaterial(color: THREE.ColorRepresentation, rim: THREE.ColorRepresentation): THREE.ShaderMaterial {
  return createCelMaterial({
    color,
    rimColor: rim,
    fillColor: '#506ea0',
    specularBand: 0.86,
    specularStrength: 0.22,
    ambient: 0.52,
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

function makeBox(size: THREE.Vector3, material: THREE.Material): THREE.Mesh {
  return new THREE.Mesh(new THREE.BoxGeometry(size.x, size.y, size.z, 1, 1, 1), material);
}

function makeSphere(radius: number, material: THREE.Material, widthSegments = 16): THREE.Mesh {
  return new THREE.Mesh(new THREE.SphereGeometry(radius, widthSegments, 10), material);
}

function makeLimb(
  root: THREE.Group,
  name: string,
  radius: number,
  length: number,
  material: THREE.Material,
  ink: THREE.ColorRepresentation,
  meshes: THREE.Mesh[],
): THREE.Group {
  const limb = new THREE.Group();
  limb.name = name;
  const mesh = makeCapsule(radius, length, material, 8);
  mesh.name = `${name}_capsule`;
  mesh.position.y = -length * 0.5;
  addOutlinedMesh(limb, mesh, ink, radius * 0.22, meshes);
  root.add(limb);
  return limb;
}

function addCape(
  torso: THREE.Group,
  colors: Required<FigureColors>,
  scale: number,
  meshes: THREE.Mesh[],
): void {
  const cape = makeBox(
    new THREE.Vector3(0.5 * scale, 0.9 * scale, 0.08 * scale),
    makeMaterial(colors.cloth, colors.rim),
  );
  cape.name = 'cape_panel';
  cape.position.set(-0.16 * scale, -0.08 * scale, -0.23 * scale);
  cape.rotation.z = 0.11;
  addOutlinedMesh(torso, cape, colors.ink, 0.02 * scale, meshes);
}

function addShoulderPad(
  parent: THREE.Group,
  side: number,
  colors: Required<FigureColors>,
  scale: number,
  meshes: THREE.Mesh[],
): void {
  const pad = makeBox(
    new THREE.Vector3(0.28 * scale, 0.18 * scale, 0.34 * scale),
    makeMaterial(colors.armor, colors.rim),
  );
  pad.name = side < 0 ? 'left_shoulder_pad' : 'right_shoulder_pad';
  pad.position.set(0.05 * scale, 0.05 * scale, side * 0.16 * scale);
  pad.rotation.x = side * 0.12;
  addOutlinedMesh(parent, pad, colors.ink, 0.018 * scale, meshes);
}

function buildWeapon(
  weaponRoot: THREE.Group,
  options: RigOptions,
  colors: Required<FigureColors>,
  scale: number,
  meshes: THREE.Mesh[],
): void {
  const weaponMat = makeMaterial(colors.weapon, colors.rim);
  const accentMat = makeMaterial(colors.accent, colors.rim);
  const boneMat = makeMaterial(colors.bone, colors.rim);
  const magicMat = makeMaterial(colors.magic, colors.rim);

  if (options.weapon === 'sword') {
    const blade = makeBox(new THREE.Vector3(0.13 * scale, 0.88 * scale, 0.08 * scale), weaponMat);
    blade.name = 'sword_blade';
    blade.position.y = -0.46 * scale;
    addOutlinedMesh(weaponRoot, blade, colors.ink, 0.014 * scale, meshes);
    const guard = makeBox(new THREE.Vector3(0.46 * scale, 0.1 * scale, 0.1 * scale), accentMat);
    guard.name = 'sword_guard';
    guard.position.y = -0.08 * scale;
    addOutlinedMesh(weaponRoot, guard, colors.ink, 0.012 * scale, meshes);
  } else if (options.weapon === 'daggers') {
    for (const side of [-1, 1]) {
      const dagger = makeBox(new THREE.Vector3(0.08 * scale, 0.44 * scale, 0.06 * scale), weaponMat);
      dagger.name = side < 0 ? 'left_dagger' : 'right_dagger';
      dagger.position.set(side * 0.07 * scale, -0.28 * scale, side * 0.03 * scale);
      dagger.rotation.z = side * 0.3;
      addOutlinedMesh(weaponRoot, dagger, colors.ink, 0.011 * scale, meshes);
    }
  } else if (options.weapon === 'staff' || options.weapon === 'boneStaff') {
    const staffMat = options.weapon === 'boneStaff' ? boneMat : weaponMat;
    const shaft = makeCapsule(0.048 * scale, 1.34 * scale, staffMat, 8);
    shaft.name = 'staff_shaft';
    shaft.position.y = -0.52 * scale;
    addOutlinedMesh(weaponRoot, shaft, colors.ink, 0.012 * scale, meshes);
    const orb = makeSphere(0.18 * scale, magicMat, 12);
    orb.name = 'staff_focus';
    orb.position.y = 0.18 * scale;
    addOutlinedMesh(weaponRoot, orb, colors.ink, 0.014 * scale, meshes);
  } else if (options.weapon === 'bow') {
    const bow = new THREE.Mesh(new THREE.TorusGeometry(0.38 * scale, 0.034 * scale, 6, 18, Math.PI * 1.35), weaponMat);
    bow.name = 'bow_arc';
    bow.rotation.z = Math.PI * 0.5;
    bow.position.y = -0.3 * scale;
    addOutlinedMesh(weaponRoot, bow, colors.ink, 0.012 * scale, meshes);
    const string = makeBox(new THREE.Vector3(0.03 * scale, 0.72 * scale, 0.03 * scale), accentMat);
    string.name = 'bow_string_block';
    string.position.y = -0.3 * scale;
    addOutlinedMesh(weaponRoot, string, colors.ink, 0.008 * scale, meshes);
  } else if (options.weapon === 'club') {
    const club = makeCapsule(0.09 * scale, 0.78 * scale, weaponMat, 10);
    club.name = 'golem_club';
    club.position.y = -0.45 * scale;
    club.scale.x = 1.55;
    club.scale.z = 1.2;
    addOutlinedMesh(weaponRoot, club, colors.ink, 0.02 * scale, meshes);
  } else {
    const claw = makeBox(new THREE.Vector3(0.1 * scale, 0.38 * scale, 0.07 * scale), weaponMat);
    claw.name = 'bone_claw';
    claw.position.y = -0.22 * scale;
    claw.rotation.z = -0.45;
    addOutlinedMesh(weaponRoot, claw, colors.ink, 0.01 * scale, meshes);
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
  parts.body.position.y += breath * 0.035;
  parts.torso.rotation.z += breath * 0.025;
  parts.head.rotation.z -= breath * 0.018;
  parts.leftArm.rotation.z += 0.08 + breath * 0.06;
  parts.rightArm.rotation.z -= 0.08 + breath * 0.05;
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

function buildFigure(options: RigOptions, colorsInput: FigureColors, label: string): ProceduralFigure {
  const colors = mergeColors(colorsInput);
  const root = new THREE.Group();
  root.name = `${label}_figure_root`;
  const partsMeshes: THREE.Mesh[] = [];
  const scale = options.scale;
  const body = new THREE.Group();
  body.name = 'figure_body';
  body.position.y = 0;
  root.add(body);

  const armorMat = makeMaterial(options.skeleton ? colors.bone : colors.armor, colors.rim);
  const clothMat = makeMaterial(colors.cloth, colors.rim);
  const skinMat = makeMaterial(options.skeleton ? colors.bone : colors.skin, colors.rim);
  const accentMat = makeMaterial(colors.accent, colors.rim);

  const hips = new THREE.Group();
  hips.name = 'hips';
  hips.position.y = 0.82 * scale;
  body.add(hips);
  const hipMesh = makeBox(
    new THREE.Vector3(0.46 * options.stocky * scale, 0.28 * scale, 0.42 * scale),
    options.skeleton ? armorMat : clothMat,
  );
  hipMesh.name = 'hips_block';
  addOutlinedMesh(hips, hipMesh, colors.ink, 0.022 * scale, partsMeshes);

  const torso = new THREE.Group();
  torso.name = 'torso';
  torso.position.y = 1.22 * scale;
  body.add(torso);
  const torsoMesh = makeBox(
    new THREE.Vector3(0.66 * options.stocky * scale, 0.76 * scale, 0.46 * scale),
    armorMat,
  );
  torsoMesh.name = 'torso_block';
  torsoMesh.rotation.z = -0.05;
  addOutlinedMesh(torso, torsoMesh, colors.ink, 0.028 * scale, partsMeshes);

  if (options.cape) addCape(torso, colors, scale, partsMeshes);

  const head = new THREE.Group();
  head.name = 'head';
  head.position.y = 1.78 * scale;
  body.add(head);
  const headMesh = makeSphere(0.22 * options.headScale * scale, skinMat, options.skeleton ? 12 : 16);
  headMesh.name = 'head_sphere';
  headMesh.scale.y = options.skeleton ? 1.12 : 1;
  addOutlinedMesh(head, headMesh, colors.ink, 0.022 * scale, partsMeshes);

  if (options.hood) {
    const hood = new THREE.Mesh(new THREE.ConeGeometry(0.28 * scale, 0.28 * scale, 4), clothMat);
    hood.name = 'hood_cowl';
    hood.position.set(-0.02 * scale, 0.02 * scale, 0);
    hood.rotation.y = Math.PI * 0.25;
    addOutlinedMesh(head, hood, colors.ink, 0.018 * scale, partsMeshes);
  }

  const leftArm = makeLimb(body, 'left_upper_arm', 0.1 * scale, 0.48 * scale, armorMat, colors.ink, partsMeshes);
  const rightArm = makeLimb(body, 'right_upper_arm', 0.1 * scale, 0.48 * scale, armorMat, colors.ink, partsMeshes);
  leftArm.position.set(0, 1.48 * scale, -0.34 * scale);
  rightArm.position.set(0, 1.48 * scale, 0.34 * scale);
  leftArm.rotation.z = 0.32;
  rightArm.rotation.z = -0.44;

  const leftForearm = makeLimb(
    leftArm,
    'left_forearm',
    0.086 * scale,
    0.42 * scale,
    skinMat,
    colors.ink,
    partsMeshes,
  );
  const rightForearm = makeLimb(
    rightArm,
    'right_forearm',
    0.086 * scale,
    0.42 * scale,
    skinMat,
    colors.ink,
    partsMeshes,
  );
  leftForearm.position.y = -0.47 * scale;
  rightForearm.position.y = -0.47 * scale;
  leftForearm.rotation.z = -0.28;
  rightForearm.rotation.z = -0.15;

  if (options.shoulderPads) {
    addShoulderPad(leftArm, -1, colors, scale, partsMeshes);
    addShoulderPad(rightArm, 1, colors, scale, partsMeshes);
  }

  const leftLeg = makeLimb(body, 'left_thigh', 0.12 * scale, 0.54 * scale, clothMat, colors.ink, partsMeshes);
  const rightLeg = makeLimb(body, 'right_thigh', 0.12 * scale, 0.54 * scale, clothMat, colors.ink, partsMeshes);
  leftLeg.position.set(0, 0.74 * scale, -0.17 * scale);
  rightLeg.position.set(0, 0.74 * scale, 0.17 * scale);
  leftLeg.rotation.z = 0.08;
  rightLeg.rotation.z = -0.08;

  const leftShin = makeLimb(leftLeg, 'left_shin', 0.098 * scale, 0.5 * scale, armorMat, colors.ink, partsMeshes);
  const rightShin = makeLimb(rightLeg, 'right_shin', 0.098 * scale, 0.5 * scale, armorMat, colors.ink, partsMeshes);
  leftShin.position.y = -0.52 * scale;
  rightShin.position.y = -0.52 * scale;
  leftShin.rotation.z = -0.12;
  rightShin.rotation.z = 0.12;

  const bootMat = options.skeleton ? skinMat : accentMat;
  for (const shin of [leftShin, rightShin]) {
    const boot = makeBox(new THREE.Vector3(0.34 * scale, 0.15 * scale, 0.18 * scale), bootMat);
    boot.name = `${shin.name}_foot`;
    boot.position.set(0.11 * scale, -0.52 * scale, 0);
    addOutlinedMesh(shin, boot, colors.ink, 0.012 * scale, partsMeshes);
  }

  const weapon = new THREE.Group();
  weapon.name = 'weapon';
  weapon.position.set(0.13 * scale, -0.38 * scale, 0.02 * scale);
  weapon.rotation.z = options.weapon === 'bow' ? -0.55 : -0.22;
  rightForearm.add(weapon);
  buildWeapon(weapon, options, colors, scale, partsMeshes);

  const offhand = new THREE.Group();
  offhand.name = 'offhand';
  offhand.position.set(0.08 * scale, -0.36 * scale, -0.01 * scale);
  leftForearm.add(offhand);
  if (options.weapon === 'sword' && !options.skeleton) {
    const shield = makeBox(new THREE.Vector3(0.16 * scale, 0.48 * scale, 0.44 * scale), accentMat);
    shield.name = 'kite_shield';
    shield.rotation.z = 0.1;
    addOutlinedMesh(offhand, shield, colors.ink, 0.018 * scale, partsMeshes);
  }

  if (options.elite) {
    const crest = new THREE.Mesh(new THREE.ConeGeometry(0.18 * scale, 0.32 * scale, 4), accentMat);
    crest.name = 'elite_crest';
    crest.position.y = 0.24 * scale;
    crest.rotation.y = Math.PI * 0.25;
    addOutlinedMesh(head, crest, colors.ink, 0.018 * scale, partsMeshes);
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

  return { root, parts, setFacing, updateAnim };
}

export function buildPlayerFigure(classId: PlayerFigureClassId, colors: FigureColors = {}): ProceduralFigure {
  return buildFigure(PLAYER_DEFAULTS[classId], { ...PLAYER_COLORS[classId], ...colors }, `player_${classId}`);
}

export function buildEnemyFigure(kind: EnemyFigureKind, colors: FigureColors = {}): ProceduralFigure {
  return buildFigure(ENEMY_DEFAULTS[kind], { ...ENEMY_COLORS[kind], ...colors }, `enemy_${kind}`);
}
