import * as THREE from 'three';
import type { ActorVisual } from '../actors/ActorVisual';
import { KayKitFigure, type KayKitFigureOptions } from '../actors/KayKitFigure';
import {
  KAYKIT_ANIMATION_BANKS,
  KAYKIT_MODELS,
  disposeObject3D,
  hasCachedGLTF,
} from '../assets/KayKitLoader';
import { attachOutline, createCelMaterial } from '../render/CelMaterial';
import type { BossIdentity, BossIdentityId } from './BossIdentities';

const CORE_HOT_TINT = new THREE.Color('#ffffff');
const BLACK = new THREE.Color('#000000');

/**
 * Boss ink weights. These are deliberately the heaviest in the game — a boss
 * must read as an order of magnitude more important than an enemy, and outline
 * width is the cheapest way to say so.
 */
const INK = {
  core: 0.075,
  head: 0.068,
  limb: 0.052,
  plate: 0.044,
  prop: 0.034,
  detail: 0.022,
} as const;

const SHIELD_PLATES = 6;

function hex(c: THREE.Color): string {
  return `#${c.getHexString()}`;
}

interface KayKitBossSpec {
  readonly modelUrl: string;
  readonly animationBankUrls: readonly string[];
  readonly targetHeight: number;
  readonly clipPreferences?: KayKitFigureOptions['clipPreferences'];
}

const MEDIUM_BOSS_BANKS = [
  KAYKIT_ANIMATION_BANKS.medium.general,
  KAYKIT_ANIMATION_BANKS.medium.movement,
  KAYKIT_ANIMATION_BANKS.medium.melee,
  KAYKIT_ANIMATION_BANKS.medium.ranged,
] as const;

const LARGE_BOSS_BANKS = [
  KAYKIT_ANIMATION_BANKS.large.general,
  KAYKIT_ANIMATION_BANKS.large.movement,
  KAYKIT_ANIMATION_BANKS.large.melee,
] as const;

const KAYKIT_BOSSES: Record<BossIdentityId, KayKitBossSpec> = {
  kallos: {
    modelUrl: KAYKIT_MODELS.kallos,
    animationBankUrls: LARGE_BOSS_BANKS,
    targetHeight: 4.4,
    clipPreferences: { attack: ['Melee_2H_Slam', 'Melee_Unarmed_Smash'] },
  },
  vesperra: {
    modelUrl: KAYKIT_MODELS.vesperra,
    animationBankUrls: MEDIUM_BOSS_BANKS,
    targetHeight: 3.8,
    clipPreferences: { cast: ['Ranged_Magic_Spellcasting_Long', 'Ranged_Magic_Summon'] },
  },
  crit0n: {
    modelUrl: KAYKIT_MODELS.crit0n,
    animationBankUrls: MEDIUM_BOSS_BANKS,
    targetHeight: 4.1,
    clipPreferences: { attack: ['Melee_Unarmed_Attack_Punch_A', 'Melee_1H_Attack_Chop'] },
  },
  pale_wager: {
    modelUrl: KAYKIT_MODELS.paleWager,
    animationBankUrls: LARGE_BOSS_BANKS,
    targetHeight: 4.3,
  },
  choir_broken_sevens: {
    modelUrl: KAYKIT_MODELS.choirBrokenSevens,
    animationBankUrls: MEDIUM_BOSS_BANKS,
    targetHeight: 3.9,
    clipPreferences: { cast: ['Ranged_Magic_Spellcasting', 'Ranged_Magic_Summon'] },
  },
  umbra_bent_die: {
    modelUrl: KAYKIT_MODELS.umbraBentDie,
    animationBankUrls: LARGE_BOSS_BANKS,
    targetHeight: 4.55,
  },
  aureline_loaded_saint: {
    modelUrl: KAYKIT_MODELS.aurelineLoadedSaint,
    animationBankUrls: MEDIUM_BOSS_BANKS,
    targetHeight: 4.05,
  },
  twentyfold_sovereign: {
    modelUrl: KAYKIT_MODELS.twentyfoldSovereign,
    animationBankUrls: LARGE_BOSS_BANKS,
    targetHeight: 4.8,
  },
};

function bossAssetsCached(spec: KayKitBossSpec): boolean {
  return hasCachedGLTF(spec.modelUrl) && spec.animationBankUrls.every(hasCachedGLTF);
}

function buildKayKitBossVisual(identity: BossIdentity, spec: KayKitBossSpec): THREE.Group {
  const root = new THREE.Group();
  root.name = `boss_${identity.id}_kaykit`;

  const figure = new KayKitFigure({
    ...spec,
    name: `boss_${identity.id}`,
  });
  figure.setFacing(-1);
  root.add(figure.root);

  const bossScale = spec.targetHeight / 4.2;
  const coreY = spec.targetHeight * 0.56;
  const ink = hex(new THREE.Color(identity.accentColor).lerp(BLACK, 0.88));
  const coreMat = createCelMaterial({
    color: identity.secondaryColor,
    rimColor: '#fff6d0',
    ambient: 0.62,
    specularBand: 0.74,
    specularStrength: 0.6,
    rimStrength: 0.85,
  });
  const coreRig = new THREE.Group();
  coreRig.name = 'boss_core_rig';
  coreRig.position.set(0, coreY, 0.54);
  root.add(coreRig);
  const core = new THREE.Mesh(new THREE.OctahedronGeometry(0.34 * bossScale, 0), coreMat);
  core.name = 'boss_core';
  core.userData.baseColor = new THREE.Color(identity.secondaryColor);
  coreRig.add(core);
  attachOutline(coreRig, core, ink, 0.026);

  const shieldRoot = new THREE.Group();
  shieldRoot.name = 'boss_shield';
  shieldRoot.position.set(0, coreY, 0.46);
  root.add(shieldRoot);
  const shieldMat = createCelMaterial({
    color: identity.accentColor,
    rimColor: identity.secondaryColor,
    fillColor: identity.secondaryColor,
    matcapMix: 0.2,
    ambient: 0.48,
    specularStrength: 0.5,
    rimStrength: 1,
  });
  for (let i = 0; i < SHIELD_PLATES; i++) {
    const angle = (i / SHIELD_PLATES) * Math.PI * 2;
    const plateRig = new THREE.Group();
    plateRig.name = `boss_shield_plate_${i}`;
    plateRig.userData.angle = angle;
    plateRig.position.set(
      Math.cos(angle) * 0.78 * bossScale,
      Math.sin(angle) * 0.78 * bossScale,
      0.18,
    );
    plateRig.rotation.z = angle;
    shieldRoot.add(plateRig);
    const plate = new THREE.Mesh(
      new THREE.CylinderGeometry(0.3 * bossScale, 0.3 * bossScale, 0.09, 6),
      shieldMat,
    );
    plate.rotation.x = Math.PI * 0.5;
    plateRig.add(plate);
    attachOutline(plateRig, plate, ink, 0.021);
  }

  root.userData.actorVisual = figure;
  root.userData.idlePhase = Math.random() * Math.PI * 2;
  root.userData.shieldT = 1;
  root.userData.bossScale = bossScale;
  root.updateMatrixWorld(true);
  const visualBounds = new THREE.Box3().setFromObject(root);
  root.userData.visualCenterY = (visualBounds.min.y + visualBounds.max.y) * 0.5;
  root.userData.visualHalfHeight = (visualBounds.max.y - visualBounds.min.y) * 0.5 + 0.12;
  return root;
}

/** Uses preloaded production art, retaining the procedural visual as a load-failure fallback. */
export function buildBossVisual(identity: BossIdentity): THREE.Group {
  const spec = KAYKIT_BOSSES[identity.id];
  return bossAssetsCached(spec)
    ? buildKayKitBossVisual(identity, spec)
    : buildProceduralBossVisual(identity);
}

/** Procedural 3D cel-shaded boss silhouette — never a billboard. */
function buildProceduralBossVisual(identity: BossIdentity): THREE.Group {
  const root = new THREE.Group();
  root.name = `boss_${identity.id}`;

  const accent = new THREE.Color(identity.accentColor);
  const secondary = new THREE.Color(identity.secondaryColor);

  // Four-zone split, same rule as the player figures: if the accent colour
  // covers the whole body it stops being an accent and the boss reads flat.
  // The shell is pushed deep on purpose — a boss should be the darkest large
  // mass on screen so its silhouette separates from a bright sky.
  const shell = accent.clone().lerp(BLACK, 0.82).lerp(secondary, 0.08);
  const shellDark = shell.clone().multiplyScalar(0.6);
  const inkColor = accent.clone().lerp(BLACK, 0.88);
  const ink = hex(inkColor);

  // Rim is kept low on the shell: on a large curved mass a strong rim wraps
  // most of the visible surface and erases the dark value the silhouette needs.
  // The plates and core carry the glow instead.
  const shellMat = createCelMaterial({
    color: hex(shell),
    rimColor: identity.secondaryColor,
    fillColor: identity.secondaryColor,
    matcapMix: 0.14,
    ambient: 0.3,
    specularBand: 0.92,
    specularStrength: 0.16,
    rimStrength: 0.3,
  });
  const shellDarkMat = createCelMaterial({
    color: hex(shellDark),
    rimColor: identity.secondaryColor,
    matcapMix: 0.08,
    ambient: 0.24,
    specularStrength: 0.08,
    rimStrength: 0.22,
  });
  // The dedicated accent — restricted to plates and crown so it stays loud.
  const plateMat = createCelMaterial({
    color: identity.accentColor,
    rimColor: identity.secondaryColor,
    fillColor: identity.secondaryColor,
    matcapMix: 0.26,
    ambient: 0.5,
    specularBand: 0.78,
    specularStrength: 0.55,
    rimStrength: 0.9,
  });
  const coreMat = createCelMaterial({
    color: identity.secondaryColor,
    rimColor: '#fff6d0',
    ambient: 0.62,
    specularBand: 0.74,
    specularStrength: 0.6,
    rimStrength: 0.85,
  });
  const boneMat = createCelMaterial({
    color: '#efe3cc',
    rimColor: identity.secondaryColor,
    ambient: 0.5,
  });

  /**
   * Tier growth is deliberately gentle. At 0.1 per tier the Sovereign stood
   * roughly 12.7 units tall against a 3.8-unit player, which no pullback can
   * frame without shrinking the player past legibility. A boss that cannot
   * share the frame with the player is not monumental, it is off-screen.
   */
  const scale = 1.25 + identity.difficultyTier * 0.062;

  // Pelvis / lower mass — angular so the boss never reads as stacked spheres
  const hips = new THREE.Mesh(new THREE.OctahedronGeometry(0.95, 0), shellDarkMat);
  hips.position.y = 1.1 * scale;
  hips.scale.set(1.25 * scale, 0.85 * scale, 0.95 * scale);
  hips.rotation.y = Math.PI * 0.25;
  root.add(hips);
  attachOutline(root, hips, ink, INK.limb);

  // Torso — flattened capsule for readable side silhouette
  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(1.05, 1.35, 8, 14), shellMat);
  torso.position.y = 2.35 * scale;
  torso.scale.set(scale, scale, scale * 0.72);
  root.add(torso);
  attachOutline(root, torso, ink, INK.core);

  // Chest plate carries the accent as a band, not as the whole mass
  const chestPlate = new THREE.Mesh(new THREE.CylinderGeometry(0.98, 1.12, 0.7, 6), plateMat);
  chestPlate.position.set(0, 2.15 * scale, 0.16);
  chestPlate.scale.set(scale * 0.94, scale, scale * 0.62);
  chestPlate.rotation.y = Math.PI * 0.5;
  root.add(chestPlate);
  attachOutline(root, chestPlate, ink, INK.plate);

  // Neck column keeps the head visually welded to the torso mass
  const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.55, 0.6, 12), shellDarkMat);
  neck.position.y = 3.45 * scale;
  root.add(neck);
  attachOutline(root, neck, ink, INK.detail);

  // Head / helm
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.72, 16, 12), shellMat);
  head.position.y = 3.85 * scale;
  head.scale.set(1.15, 1.05, 0.95);
  root.add(head);
  attachOutline(root, head, ink, INK.head);

  const brow = new THREE.Mesh(new THREE.BoxGeometry(1.35, 0.24, 0.9), plateMat);
  brow.position.set(0, 4.02 * scale, 0.18);
  brow.rotation.z = 0.06;
  root.add(brow);
  attachOutline(root, brow, ink, INK.plate);

  const jaw = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.35, 0.55), shellDarkMat);
  jaw.position.set(0, 3.35 * scale, 0.35);
  root.add(jaw);
  attachOutline(root, jaw, ink, INK.detail);

  /**
   * Crown spires. Vertical arenas are built from horizontal ledges, so the
   * boss breaks that rhythm with a tall asymmetric stack rather than reading
   * as one more wide shape in a row of wide shapes.
   */
  const spireHeights = [1.9, 2.9, 1.4];
  const spireOffsets = [-0.55, -0.05, 0.5];
  for (let i = 0; i < spireHeights.length; i++) {
    const h = spireHeights[i]! * scale * 0.55;
    const spire = new THREE.Mesh(new THREE.ConeGeometry(0.2 + i * 0.03, h, 4), plateMat);
    spire.name = `boss_crown_spire_${i}`;
    spire.position.set(spireOffsets[i]! * scale, 4.4 * scale + h * 0.5, 0);
    spire.rotation.y = Math.PI * 0.25;
    spire.rotation.z = spireOffsets[i]! * 0.14;
    root.add(spire);
    attachOutline(root, spire, ink, INK.prop);
  }

  // Arms
  for (const side of [-1, 1] as const) {
    // Asymmetric pauldrons: the left shoulder carries visibly more mass so the
    // boss has a readable "heavy side" instead of mirror symmetry.
    const padScale = side < 0 ? 1.32 : 1.0;
    const shoulder = new THREE.Mesh(new THREE.ConeGeometry(0.62 * padScale, 0.8 * padScale, 5), plateMat);
    shoulder.position.set(side * 1.25 * scale, 3.0 * scale, 0);
    shoulder.rotation.z = side * 1.9;
    shoulder.rotation.y = Math.PI * 0.2;
    root.add(shoulder);
    attachOutline(root, shoulder, ink, INK.plate);

    const upper = new THREE.Mesh(new THREE.CapsuleGeometry(0.3, 0.85, 6, 10), shellMat);
    upper.position.set(side * 1.55 * scale, 2.15 * scale, 0.1);
    upper.rotation.z = side * 0.35;
    root.add(upper);
    attachOutline(root, upper, ink, INK.limb);

    // Forearm bridges the upper arm into the fist — no floating hands
    const forearm = new THREE.Mesh(new THREE.CapsuleGeometry(0.26, 0.6, 6, 10), shellDarkMat);
    forearm.position.set(side * 1.74 * scale, 1.72 * scale, 0.12);
    forearm.rotation.z = side * 0.18;
    root.add(forearm);
    attachOutline(root, forearm, ink, INK.limb);

    const fist = new THREE.Mesh(new THREE.SphereGeometry(0.36, 10, 8), boneMat);
    fist.position.set(side * 1.85 * scale, 1.45 * scale, 0.15);
    root.add(fist);
    attachOutline(root, fist, ink, INK.prop);

    const horn = new THREE.Mesh(new THREE.ConeGeometry(0.2, 1.05, 6), coreMat);
    horn.position.set(side * 0.42, 4.45 * scale, 0);
    horn.rotation.z = side * 0.42;
    root.add(horn);
    attachOutline(root, horn, ink, INK.prop);
  }

  /**
   * Chest core gem. Wrapped in a rig group so the DPS-window scale pulse takes
   * the outline with it — scaling a bare mesh leaves its inverted hull behind
   * and the ink vanishes exactly when the target matters most.
   */
  const coreGemMat = createCelMaterial({
    color: identity.secondaryColor,
    rimColor: '#fff6d0',
    ambient: 0.6,
    specularBand: 0.78,
    specularStrength: 0.6,
    rimStrength: 0.8,
  });
  const coreRig = new THREE.Group();
  coreRig.name = 'boss_core_rig';
  coreRig.position.set(0, 2.45 * scale, 0.62);
  root.add(coreRig);
  const core = new THREE.Mesh(new THREE.OctahedronGeometry(0.46, 0), coreGemMat);
  core.name = 'boss_core';
  core.userData.baseColor = new THREE.Color(identity.secondaryColor);
  coreRig.add(core);
  attachOutline(coreRig, core, ink, INK.prop);

  /**
   * Shield shell: solid hex plates ringed around the core. Present means the
   * boss is protected; retracted means the DPS window is open. Solid rather
   * than translucent so the state reads as a shape change, not a glow change.
   */
  const shieldRoot = new THREE.Group();
  shieldRoot.name = 'boss_shield';
  shieldRoot.position.set(0, 2.45 * scale, 0.5);
  root.add(shieldRoot);
  const shieldMat = createCelMaterial({
    color: identity.accentColor,
    rimColor: identity.secondaryColor,
    fillColor: identity.secondaryColor,
    matcapMix: 0.2,
    ambient: 0.44,
    specularBand: 0.76,
    specularStrength: 0.5,
    rimStrength: 1.0,
  });
  for (let i = 0; i < SHIELD_PLATES; i++) {
    const a = (i / SHIELD_PLATES) * Math.PI * 2;
    const plateRig = new THREE.Group();
    plateRig.name = `boss_shield_plate_${i}`;
    plateRig.userData.angle = a;
    plateRig.position.set(Math.cos(a) * 1.05 * scale, Math.sin(a) * 1.05 * scale, 0.22);
    plateRig.rotation.z = a;
    shieldRoot.add(plateRig);
    const plate = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.11, 6), shieldMat);
    plate.rotation.x = Math.PI * 0.5;
    plateRig.add(plate);
    attachOutline(plateRig, plate, ink, INK.plate);
  }

  // Elemental dress
  if (identity.element === 'frost') {
    for (let i = 0; i < 7; i++) {
      const spike = new THREE.Mesh(new THREE.ConeGeometry(0.14, 0.95, 5), coreMat);
      const a = (i / 7) * Math.PI * 2;
      spike.position.set(Math.cos(a) * 1.55 * scale, 1.35 * scale, Math.sin(a) * 0.55);
      spike.rotation.z = -a + Math.PI / 2;
      root.add(spike);
      attachOutline(root, spike, ink, INK.detail);
    }
    const crown = new THREE.Mesh(new THREE.TorusGeometry(0.85, 0.08, 6, 20), coreMat);
    crown.rotation.x = Math.PI / 2.4;
    crown.position.y = 4.15 * scale;
    root.add(crown);
  } else if (identity.element === 'void') {
    const ring = new THREE.Mesh(new THREE.TorusGeometry(1.65, 0.1, 6, 28), coreMat);
    ring.rotation.x = Math.PI / 2;
    ring.position.y = 2.4 * scale;
    root.add(ring);
    const ring2 = ring.clone();
    ring2.scale.setScalar(0.7);
    ring2.rotation.z = 0.5;
    root.add(ring2);
  } else if (identity.element === 'forge') {
    for (const side of [-1, 1]) {
      const arc = new THREE.Mesh(new THREE.TorusGeometry(1.2, 0.07, 6, 20, Math.PI), coreMat);
      arc.position.set(side * 0.2, 3.4 * scale, 0.25);
      arc.rotation.z = side * 0.2;
      root.add(arc);
    }
    const anvil = new THREE.Mesh(new THREE.BoxGeometry(1.6, 0.35, 0.8), shellDarkMat);
    anvil.position.y = 0.55 * scale;
    root.add(anvil);
    attachOutline(root, anvil, ink, INK.detail);
  } else {
    const die = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.7, 0.7), coreMat);
    die.position.set(1.85 * scale, 3.7 * scale, 0.2);
    die.name = 'fate_die';
    root.add(die);
    attachOutline(root, die, ink, INK.detail);
    const die2 = die.clone();
    die2.position.set(-1.7 * scale, 3.2 * scale, -0.1);
    die2.scale.setScalar(0.7);
    root.add(die2);
  }

  root.userData.idlePhase = Math.random() * Math.PI * 2;
  root.userData.shieldT = 1;
  root.userData.bossScale = scale;
  /**
   * Published framing extents. The root sits at the boss's feet while the crown
   * reaches ~6 units of scale above it, so a camera that focuses on the root
   * position frames the ankles and clips the head clean off the top.
   */
  root.userData.visualCenterY = 3.0 * scale;
  root.userData.visualHalfHeight = 3.2 * scale;
  return root;
}

export function updateBossVisual(root: THREE.Group, dt: number, vulnerable: boolean): void {
  const actorVisual = root.userData.actorVisual as ActorVisual | undefined;
  actorVisual?.updateAnim(dt, { name: 'idle' });
  root.userData.idlePhase = (root.userData.idlePhase as number) + dt;
  const t = root.userData.idlePhase as number;
  if (root.userData.baseY === undefined) root.userData.baseY = root.position.y;
  root.position.y = (root.userData.baseY as number) + Math.sin(t * 1.4) * 0.12;
  root.rotation.y = Math.sin(t * 0.45) * 0.1;

  // Shield state eased so the transition is a visible mechanical retraction
  // rather than a pop, but fast enough to be a clear combat signal.
  const target = vulnerable ? 0 : 1;
  const prev = (root.userData.shieldT as number | undefined) ?? 1;
  const shieldT = THREE.MathUtils.clamp(prev + (target - prev) * Math.min(1, dt * 7), 0, 1);
  root.userData.shieldT = shieldT;

  const scale = (root.userData.bossScale as number | undefined) ?? 1;
  const shield = root.getObjectByName('boss_shield');
  if (shield) {
    shield.rotation.z += dt * (vulnerable ? 2.4 : 0.5);
    for (const plateRig of shield.children) {
      const a = plateRig.userData.angle as number | undefined;
      if (a === undefined) continue;
      // Plates fly outward and shrink as the window opens.
      const radius = (1.05 + (1 - shieldT) * 1.1) * scale;
      plateRig.position.set(Math.cos(a) * radius, Math.sin(a) * radius, 0.22);
      plateRig.scale.setScalar(Math.max(0.0001, shieldT));
      plateRig.visible = shieldT > 0.02;
    }
  }

  const coreRig = root.getObjectByName('boss_core_rig');
  const core = root.getObjectByName('boss_core');
  if (coreRig) {
    // Scale the rig, not the mesh, so the inverted-hull outline pulses too.
    coreRig.scale.setScalar(vulnerable ? 1.35 + Math.sin(t * 9) * 0.14 : 1);
  }
  if (core) {
    core.rotation.x += dt * 1.5;
    core.rotation.y += dt * 2.2;
    // DPS window: push the gem's secondary tint toward white-hot so the
    // vulnerable state reads at a glance, then restore the base color.
    if (core instanceof THREE.Mesh && core.material instanceof THREE.ShaderMaterial) {
      const uniforms = core.material.uniforms;
      const baseColor = core.userData.baseColor as THREE.Color | undefined;
      if (baseColor && uniforms.uColor) {
        const color = uniforms.uColor.value as THREE.Color;
        color.copy(baseColor);
        if (vulnerable) color.lerp(CORE_HOT_TINT, 0.35 + (Math.sin(t * 9) * 0.5 + 0.5) * 0.25);
      }
      if (uniforms.uAmbient) uniforms.uAmbient.value = vulnerable ? 0.98 : 0.6;
      if (uniforms.uRimStrength) uniforms.uRimStrength.value = vulnerable ? 1.4 : 0.8;
    }
  }

  const die = root.getObjectByName('fate_die');
  if (die) {
    die.rotation.x += dt * 0.9;
    die.rotation.y += dt * 1.2;
  }
}

export function disposeBossVisual(root: THREE.Group): void {
  const actorVisual = root.userData.actorVisual as ActorVisual | undefined;
  actorVisual?.dispose();
  disposeObject3D(root);
  root.clear();
}
