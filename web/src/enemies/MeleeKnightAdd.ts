import * as THREE from 'three';
import { EnemyBase } from './EnemyBase';
import type { FigureColors } from '../actors/ProceduralFigure';

export class MeleeKnightAdd extends EnemyBase {
  constructor(position = new THREE.Vector3(), colors: FigureColors = {}) {
    super('meleeKnightAdd', position, colors);
  }
}
