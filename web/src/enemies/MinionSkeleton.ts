import * as THREE from 'three';
import { EnemyBase, type EnemyAiContext, type EnemyFrameEvents } from './EnemyBase';
import type { FigureColors } from '../actors/ProceduralFigure';

export class MinionSkeleton extends EnemyBase {
  constructor(position = new THREE.Vector3(), colors: FigureColors = {}) {
    super('minionSkeleton', position, colors);
    this.attackCooldownRemaining = 0;
  }

  protected override appendAttackEvents(ctx: EnemyAiContext, events: EnemyFrameEvents): void {
    const before = events.melee.length;
    super.appendAttackEvents(ctx, events);
    const latest = events.melee[events.melee.length - 1];
    if (events.melee.length > before && latest && ctx.rng() < 0.28) {
      latest.status = 'bleed';
      latest.statusDuration = 2.2;
    }
  }
}
