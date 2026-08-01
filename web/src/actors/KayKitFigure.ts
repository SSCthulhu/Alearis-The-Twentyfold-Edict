import * as THREE from 'three';
import {
  KAYKIT_ANIMATION_BANKS,
  KAYKIT_MODELS,
  cloneCachedGLTF,
  getCachedGLTF,
  hasCachedGLTF,
} from '../assets/KayKitLoader';
import type { ActorVisual } from './ActorVisual';
import type {
  EnemyFigureKind,
  PlayerFigureClassId,
} from './ProceduralFigure';
import type { FigureAnimName, FigureAnimState } from './types';

type ClipPreferences = Partial<Record<FigureAnimName, readonly string[]>>;

export interface KayKitFigureOptions {
  readonly name: string;
  readonly modelUrl: string;
  readonly animationBankUrls: readonly string[];
  readonly targetHeight: number;
  readonly clipPreferences?: ClipPreferences;
}

const DEFAULT_CLIP_PREFERENCES: Record<FigureAnimName, readonly string[]> = {
  idle: ['Idle_A', 'Skeletons_Idle', 'Idle_B', 'Melee_2H_Idle'],
  walk: ['Walking_A', 'Skeletons_Walking', 'Walking_B', 'Running_A'],
  run: ['Running_A', 'Running_B', 'Walking_A'],
  jump: ['Jump_Start', 'Jump_Full_Short', 'Jump_Full_Long', 'Jump_Idle'],
  fall: ['Jump_Idle', 'Jump_Full_Long', 'Jump_Full_Short'],
  attack: [
    'Melee_1H_Attack_Slice_Horizontal',
    'Melee_1H_Slash',
    'Melee_1H_Attack_Chop',
    'Melee_2H_Attack',
    'Melee_Unarmed_Punch_A',
  ],
  cast: ['Ranged_Magic_Spellcasting', 'Ranged_Magic_Shoot', 'Ranged_Magic_Raise'],
  hurt: ['Hit_A', 'Melee_Block_Hit', 'Hit_B'],
  death: ['Death_A', 'Skeletons_Death', 'Death_B'],
};

const MEDIUM_BANKS = [
  KAYKIT_ANIMATION_BANKS.medium.general,
  KAYKIT_ANIMATION_BANKS.medium.movement,
  KAYKIT_ANIMATION_BANKS.medium.melee,
  KAYKIT_ANIMATION_BANKS.medium.ranged,
  KAYKIT_ANIMATION_BANKS.medium.special,
] as const;

const LARGE_BANKS = [
  KAYKIT_ANIMATION_BANKS.large.general,
  KAYKIT_ANIMATION_BANKS.large.movement,
  KAYKIT_ANIMATION_BANKS.large.melee,
] as const;

interface KayKitSpec {
  readonly modelUrl: string;
  readonly animationBankUrls: readonly string[];
  readonly targetHeight: number;
  readonly clipPreferences?: ClipPreferences;
}

const PLAYER_SPECS: Record<PlayerFigureClassId, KayKitSpec> = {
  knight: {
    modelUrl: KAYKIT_MODELS.knight,
    animationBankUrls: MEDIUM_BANKS,
    targetHeight: 1.98,
    clipPreferences: {
      attack: ['Melee_1H_Attack_Slice_Horizontal', 'Melee_1H_Attack_Chop'],
    },
  },
  rogue: {
    modelUrl: KAYKIT_MODELS.rogue,
    animationBankUrls: MEDIUM_BANKS,
    targetHeight: 1.94,
    clipPreferences: {
      attack: ['Melee_Dualwield_Attack_Slice', 'Melee_Dualwield_Attack_Chop'],
    },
  },
  mage: {
    modelUrl: KAYKIT_MODELS.mage,
    animationBankUrls: MEDIUM_BANKS,
    targetHeight: 2,
    clipPreferences: {
      attack: ['Ranged_Magic_Shoot', 'Ranged_Magic_Spellcasting'],
      cast: ['Ranged_Magic_Spellcasting', 'Ranged_Magic_Summon'],
    },
  },
};

const ENEMY_SPECS: Record<EnemyFigureKind, KayKitSpec> = {
  meleeKnightAdd: {
    modelUrl: KAYKIT_MODELS.meleeKnightAdd,
    animationBankUrls: MEDIUM_BANKS,
    targetHeight: 1.45,
  },
  necromancer: {
    modelUrl: KAYKIT_MODELS.necromancer,
    animationBankUrls: MEDIUM_BANKS,
    targetHeight: 1.5,
    clipPreferences: {
      attack: ['Ranged_Magic_Shoot', 'Ranged_Magic_Spellcasting'],
      cast: ['Ranged_Magic_Summon', 'Ranged_Magic_Spellcasting_Long'],
    },
  },
  skeletonMage: {
    modelUrl: KAYKIT_MODELS.skeletonMage,
    animationBankUrls: MEDIUM_BANKS,
    targetHeight: 1.4,
    clipPreferences: {
      idle: ['Skeletons_Idle', 'Idle_A'],
      walk: ['Skeletons_Walking', 'Walking_A'],
      death: ['Skeletons_Death', 'Death_A'],
      attack: ['Ranged_Magic_Shoot', 'Ranged_Magic_Spellcasting'],
      cast: ['Ranged_Magic_Spellcasting', 'Ranged_Magic_Summon'],
    },
  },
  rogueSkeleton: {
    modelUrl: KAYKIT_MODELS.rogueSkeleton,
    animationBankUrls: MEDIUM_BANKS,
    targetHeight: 1.35,
    clipPreferences: {
      idle: ['Skeletons_Idle', 'Ranged_Bow_Idle', 'Idle_A'],
      walk: ['Skeletons_Walking', 'Walking_A'],
      attack: ['Ranged_Bow_Release', 'Melee_Dualwield_Attack_Slice'],
      cast: ['Ranged_Bow_Draw', 'Ranged_Bow_Aiming_Idle'],
      death: ['Skeletons_Death', 'Death_A'],
    },
  },
  skeletonGolem: {
    modelUrl: KAYKIT_MODELS.skeletonGolem,
    animationBankUrls: LARGE_BANKS,
    targetHeight: 2.25,
    clipPreferences: {
      attack: ['Melee_2H_Slam', 'Melee_Unarmed_Smash', 'Melee_2H_Attack'],
    },
  },
  minionSkeleton: {
    modelUrl: KAYKIT_MODELS.minionSkeleton,
    animationBankUrls: MEDIUM_BANKS,
    targetHeight: 1.15,
    clipPreferences: {
      idle: ['Skeletons_Idle', 'Idle_A'],
      walk: ['Skeletons_Walking', 'Walking_A'],
      attack: ['Melee_Unarmed_Attack_Punch_A', 'Melee_1H_Attack_Chop'],
      death: ['Skeletons_Death', 'Death_A'],
    },
  },
};

function resolveClips(bankUrls: readonly string[]): Map<string, THREE.AnimationClip> {
  const clips = new Map<string, THREE.AnimationClip>();
  for (const url of bankUrls) {
    for (const clip of getCachedGLTF(url).animations) {
      if (clip.name !== 'T-Pose' && !clips.has(clip.name)) clips.set(clip.name, clip);
    }
  }
  return clips;
}

function allAssetsCached(spec: KayKitSpec): boolean {
  return hasCachedGLTF(spec.modelUrl) && spec.animationBankUrls.every(hasCachedGLTF);
}

/**
 * KayKit skinned visual normalized to a gameplay-sized, feet-origin group.
 * Inverted-hull clones are intentionally omitted: they do not share the skin
 * skeleton correctly, while the existing Sobel pass outlines the animated mesh.
 */
export class KayKitFigure implements ActorVisual {
  readonly root = new THREE.Group();

  private readonly model: THREE.Group;
  private readonly mixer: THREE.AnimationMixer;
  private readonly actions = new Map<FigureAnimName, THREE.AnimationAction>();
  private currentName: FigureAnimName | null = null;
  private facing = 1;
  private disposed = false;

  constructor(options: KayKitFigureOptions) {
    const clone = cloneCachedGLTF(options.modelUrl);
    this.model = clone.scene;
    this.root.name = `${options.name}_kaykit_root`;
    this.model.name = `${options.name}_kaykit_model`;

    this.model.traverse((object) => {
      if (!(object instanceof THREE.Mesh)) return;
      object.castShadow = true;
      object.receiveShadow = true;
      object.frustumCulled = true;
    });

    this.model.updateMatrixWorld(true);
    const sourceBounds = new THREE.Box3().setFromObject(this.model);
    const sourceHeight = sourceBounds.max.y - sourceBounds.min.y;
    if (!Number.isFinite(sourceHeight) || sourceHeight <= 0.001) {
      throw new Error(`KayKit model has invalid bounds: ${options.modelUrl}`);
    }

    const visualScale = options.targetHeight / sourceHeight;
    this.model.scale.setScalar(visualScale);
    this.model.position.y = -sourceBounds.min.y * visualScale;
    // KayKit rigs face +Z; gameplay's positive facing axis is +X.
    this.model.rotation.y = Math.PI * 0.5;
    this.root.add(this.model);
    this.root.userData.sourceHeight = sourceHeight;
    this.root.userData.visualHeight = options.targetHeight;
    this.root.userData.visualScale = visualScale;

    this.mixer = new THREE.AnimationMixer(this.model);
    const availableClips = resolveClips(options.animationBankUrls);
    for (const name of Object.keys(DEFAULT_CLIP_PREFERENCES) as FigureAnimName[]) {
      const preferred = [
        ...(options.clipPreferences?.[name] ?? []),
        ...DEFAULT_CLIP_PREFERENCES[name],
      ];
      const clipName = preferred.find((candidate) => availableClips.has(candidate));
      if (!clipName) continue;
      const clip = availableClips.get(clipName);
      if (clip) this.actions.set(name, this.mixer.clipAction(clip));
    }

    this.playState('idle');
    this.mixer.update(0);
  }

  setFacing(dir: number): void {
    const next = dir < 0 ? -1 : 1;
    if (next === this.facing) return;
    this.facing = next;
    this.root.rotation.y = next < 0 ? Math.PI : 0;
  }

  updateAnim(dt: number, state: FigureAnimState): void {
    if (this.disposed) return;
    const requested = this.actions.has(state.name) ? state.name : 'idle';
    this.playState(requested);

    const action = this.actions.get(requested);
    const locomotionScale =
      requested === 'walk' || requested === 'run'
        ? THREE.MathUtils.clamp(state.speed ?? 1, 0.45, 1.9)
        : 1;
    action?.setEffectiveTimeScale(locomotionScale);
    this.mixer.update(Math.max(0, dt));

    if (action && (requested === 'attack' || requested === 'cast') && state.attackT !== undefined) {
      action.time = THREE.MathUtils.clamp(state.attackT, 0, 1) * action.getClip().duration;
      this.mixer.update(0);
    } else if (action && requested === 'death' && state.deathT !== undefined) {
      action.time = THREE.MathUtils.clamp(state.deathT, 0, 1) * action.getClip().duration;
      this.mixer.update(0);
    }
  }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.mixer.stopAllAction();
    this.mixer.uncacheRoot(this.model);
    this.root.remove(this.model);
  }

  private playState(name: FigureAnimName): void {
    if (name === this.currentName) return;
    const next = this.actions.get(name) ?? this.actions.get('idle');
    if (!next) return;

    const previous = this.currentName ? this.actions.get(this.currentName) : undefined;
    previous?.fadeOut(0.12);
    next.reset();
    if (name === 'attack' || name === 'cast' || name === 'hurt' || name === 'death' || name === 'jump') {
      next.setLoop(THREE.LoopOnce, 1);
      next.clampWhenFinished = true;
    } else {
      next.setLoop(THREE.LoopRepeat, Number.POSITIVE_INFINITY);
      next.clampWhenFinished = false;
    }
    next.fadeIn(0.12).play();
    this.currentName = name;
  }
}

export function canBuildKayKitPlayer(classId: PlayerFigureClassId): boolean {
  return allAssetsCached(PLAYER_SPECS[classId]);
}

export function buildKayKitPlayer(classId: PlayerFigureClassId): KayKitFigure {
  const spec = PLAYER_SPECS[classId];
  return new KayKitFigure({
    ...spec,
    name: `player_${classId}`,
  });
}

export function canBuildKayKitEnemy(kind: EnemyFigureKind): boolean {
  return allAssetsCached(ENEMY_SPECS[kind]);
}

export function buildKayKitEnemy(kind: EnemyFigureKind): KayKitFigure {
  const spec = ENEMY_SPECS[kind];
  return new KayKitFigure({
    ...spec,
    name: `enemy_${kind}`,
  });
}
