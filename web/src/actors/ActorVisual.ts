import type * as THREE from 'three';
import type { FigureAnimState } from './types';

/** Render-only actor contract. Physics and gameplay remain owned by controllers. */
export interface ActorVisual {
  readonly root: THREE.Group;
  setFacing(dir: number): void;
  updateAnim(dt: number, state: FigureAnimState): void;
  dispose(): void;
}
