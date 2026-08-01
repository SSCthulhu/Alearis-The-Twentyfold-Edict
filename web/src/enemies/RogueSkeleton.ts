import * as THREE from 'three';
import { EnemyBase, type EnemyAiContext, type EnemyFrameEvents } from './EnemyBase';
import type { FigureColors } from '../actors/ProceduralFigure';

export class RogueSkeleton extends EnemyBase {
  constructor(position = new THREE.Vector3(), colors: FigureColors = {}) {
    super('rogueSkeleton', position, colors);
  }

  protected override appendAttackEvents(ctx: EnemyAiContext, events: EnemyFrameEvents): void {
    if (!this.config.projectile) {
      super.appendAttackEvents(ctx, events);
      return;
    }

    const projectile = this.createProjectileEvent(this.config.projectile, ctx.playerPosition, new THREE.Vector3(0.5, 1.16, 0));
    if (!projectile) return;

    projectile.spec.pattern = 'line';
    projectile.spec.count = 1;
    projectile.spec.speed *= 1 + Math.max(0, 1 - this.hpRatio) * 0.18;
    projectile.spec.radius = 0.14;
    events.projectiles.push(projectile);
  }
}
