import * as THREE from 'three';
import { GLTFLoader, type GLTF } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { clone as cloneSkeleton } from 'three/examples/jsm/utils/SkeletonUtils.js';
import { createCelMaterialFromStandard } from '../render/CelMaterial';

const baseUrl = import.meta.env.BASE_URL.endsWith('/')
  ? import.meta.env.BASE_URL
  : `${import.meta.env.BASE_URL}/`;

export function kayKitUrl(relativePath: string): string {
  return `${baseUrl}assets/kaykit/${relativePath}`;
}

export const KAYKIT_MODELS = {
  knight: kayKitUrl('characters/Knight.glb'),
  rogue: kayKitUrl('characters/Rogue_Hooded.glb'),
  mage: kayKitUrl('characters/Mage.glb'),
  meleeKnightAdd: kayKitUrl('enemies/Skeleton_Warrior.glb'),
  necromancer: kayKitUrl('enemies/Necromancer.glb'),
  skeletonMage: kayKitUrl('enemies/Skeleton_Mage.glb'),
  rogueSkeleton: kayKitUrl('enemies/Skeleton_Rogue.glb'),
  skeletonGolem: kayKitUrl('enemies/Skeleton_Golem.glb'),
  minionSkeleton: kayKitUrl('enemies/Skeleton_Minion.glb'),
  kallos: kayKitUrl('bosses/FrostGolem.glb'),
  vesperra: kayKitUrl('bosses/Witch.glb'),
  crit0n: kayKitUrl('bosses/CombatMech.glb'),
  paleWager: kayKitUrl('bosses/BlackKnight.glb'),
  choirBrokenSevens: kayKitUrl('bosses/Cleric.glb'),
  umbraBentDie: kayKitUrl('bosses/4GTN_Forgotten.glb'),
  aurelineLoadedSaint: kayKitUrl('bosses/Tiefling.glb'),
  twentyfoldSovereign: kayKitUrl('bosses/4GTN.glb'),
} as const;

export const KAYKIT_PROPS = {
  chest: kayKitUrl('props/chest.gltf'),
  chestGold: kayKitUrl('props/chest_gold.gltf'),
  barrelSmall: kayKitUrl('props/barrel_small.gltf'),
  crateLarge: kayKitUrl('props/crate_large.gltf'),
} as const;

export const KAYKIT_ANIMATION_BANKS = {
  medium: {
    general: kayKitUrl('anims/rig-medium/Rig_Medium_General.glb'),
    movement: kayKitUrl('anims/rig-medium/Rig_Medium_MovementBasic.glb'),
    melee: kayKitUrl('anims/rig-medium/Rig_Medium_CombatMelee.glb'),
    ranged: kayKitUrl('anims/rig-medium/Rig_Medium_CombatRanged.glb'),
    special: kayKitUrl('anims/rig-medium/Rig_Medium_Special.glb'),
  },
  large: {
    general: kayKitUrl('anims/rig-large/Rig_Large_General.glb'),
    movement: kayKitUrl('anims/rig-large/Rig_Large_MovementBasic.glb'),
    melee: kayKitUrl('anims/rig-large/Rig_Large_CombatMelee.glb'),
  },
} as const;

export interface CachedGLTFClone {
  readonly scene: THREE.Group;
  readonly animations: readonly THREE.AnimationClip[];
}

const loader = new GLTFLoader();
const cache = new Map<string, GLTF>();
const pending = new Map<string, Promise<GLTF>>();

export function hasCachedGLTF(url: string): boolean {
  return cache.has(url);
}

export async function loadGLTF(url: string): Promise<GLTF> {
  const loaded = cache.get(url);
  if (loaded) return loaded;

  const active = pending.get(url);
  if (active) return active;

  const request = loader.loadAsync(url).then(
    (gltf) => {
      cache.set(url, gltf);
      pending.delete(url);
      return gltf;
    },
    (error: unknown) => {
      pending.delete(url);
      throw error;
    },
  );
  pending.set(url, request);
  return request;
}

export function getCachedGLTF(url: string): GLTF {
  const gltf = cache.get(url);
  if (!gltf) throw new Error(`KayKit GLTF was not preloaded: ${url}`);
  return gltf;
}

/** Skeleton-aware clone; geometry, materials and textures remain cache-owned. */
export function cloneCachedGLTF(url: string): CachedGLTFClone {
  const source = getCachedGLTF(url);
  return {
    scene: cloneSkeleton(source.scene) as THREE.Group,
    animations: source.animations,
  };
}

/**
 * Cel materials converted from the KayKit PBR sources, keyed by the source
 * material's uuid. SkeletonUtils shares source materials by reference across
 * every clone, so one cel material per source is built once and reused by all
 * figures/props for the run — matching how geometry and textures are shared.
 */
const celMaterialCache = new Map<string, THREE.ShaderMaterial>();

function toCelMaterial(source: THREE.Material): THREE.Material {
  if (!(source instanceof THREE.MeshStandardMaterial)) return source;
  const cached = celMaterialCache.get(source.uuid);
  if (cached) return cached;
  const cel = createCelMaterialFromStandard(source);
  celMaterialCache.set(source.uuid, cel);
  return cel;
}

/**
 * Swaps every KayKit `MeshStandardMaterial` on a cloned scene for its self-lit
 * cel equivalent. Skinned characters otherwise render as black silhouettes:
 * they are the only meshes that rely on the scene's three lights, which the
 * rest of the self-lit cel world ignores. Textures/geometry stay cache-owned.
 */
export function applyCelMaterials(root: THREE.Object3D): void {
  root.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;
    object.material = Array.isArray(object.material)
      ? object.material.map(toCelMaterial)
      : toCelMaterial(object.material);
  });
}

function disposeMaterial(material: THREE.Material, textures: Set<THREE.Texture>): void {
  for (const value of Object.values(material)) {
    if (value instanceof THREE.Texture) textures.add(value);
  }
  material.dispose();
}

/** Releases GPU resources owned by a standalone object tree. */
export function disposeObject3D(root: THREE.Object3D): void {
  const geometries = new Set<THREE.BufferGeometry>();
  const materials = new Set<THREE.Material>();
  const textures = new Set<THREE.Texture>();

  root.traverse((object) => {
    if (!(object instanceof THREE.Mesh) || object.userData.cacheOwnedResources === true) return;
    geometries.add(object.geometry);
    const meshMaterials = Array.isArray(object.material) ? object.material : [object.material];
    for (const material of meshMaterials) materials.add(material);
  });

  for (const geometry of geometries) geometry.dispose();
  for (const material of materials) disposeMaterial(material, textures);
  for (const texture of textures) texture.dispose();
}

export function disposeCachedGLTF(url: string): void {
  const gltf = cache.get(url);
  if (!gltf) return;
  disposeObject3D(gltf.scene);
  cache.delete(url);
}

export function disposeKayKitCache(): void {
  for (const url of [...cache.keys()]) disposeCachedGLTF(url);
  for (const material of celMaterialCache.values()) material.dispose();
  celMaterialCache.clear();
  pending.clear();
}

const CRITICAL_URLS: readonly string[] = [
  ...Object.values(KAYKIT_MODELS),
  ...Object.values(KAYKIT_PROPS),
  ...Object.values(KAYKIT_ANIMATION_BANKS.medium),
  ...Object.values(KAYKIT_ANIMATION_BANKS.large),
];
const ANIMATION_BANK_URLS: readonly string[] = [
  ...Object.values(KAYKIT_ANIMATION_BANKS.medium),
  ...Object.values(KAYKIT_ANIMATION_BANKS.large),
];

/** One startup request shared by menu, character select and debug harness callers. */
export class AssetPreloader {
  private static request: Promise<void> | null = null;

  static preload(): Promise<void> {
    if (!this.request) {
      this.request = Promise.all(CRITICAL_URLS.map((url) => loadGLTF(url))).then(() => {
        // Animation clips are standalone. Drop the duplicate preview rigs bundled
        // in each bank while retaining the cached clips used by every mixer.
        for (const url of ANIMATION_BANK_URLS) {
          const gltf = getCachedGLTF(url);
          disposeObject3D(gltf.scene);
          gltf.scene.clear();
        }
      });
    }
    return this.request;
  }
}
