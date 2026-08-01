import * as THREE from 'three';
import { EnemyBase, type EnemyAiContext, type EnemyFrameEvents } from './EnemyBase';
import type { FigureColors } from '../actors/ProceduralFigure';

export class MinionSkeleton extends EnemyBase {
  constructor(position = new THREE.Vector3(), colors: FigureColors = {}) {
    super('minionSkeleton', position, colors);
    this.attackCooldownRemaining = 0;
  }

  protected override appendAttackEvents(ctx: EnemyAiContext, events: EnemyFrameEvents): void {
    super.appendAttackEvents(ctx, events);
    if (ctx.rng() < 0.28) this.statuses.apply({ id: 'bleed', duration: 1.2, sourceId: this.kind });
  }
}
