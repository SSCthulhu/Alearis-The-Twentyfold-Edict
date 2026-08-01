import * as THREE from 'three';
import { EnemyBase, type EnemyAiContext, type EnemyFrameEvents } from './EnemyBase';
import type { FigureColors } from '../actors/ProceduralFigure';

export class SkeletonMage extends EnemyBase {
  constructor(position = new THREE.Vector3(), colors: FigureColors = {}) {
    super('skeletonMage', position, colors);
  }

  protected override appendAttackEvents(ctx: EnemyAiContext, events: EnemyFrameEvents): void {
    if (!this.config.projectile) {
      super.appendAttackEvents(ctx, events);
      return;
    }

    const projectile = this.createProjectileEvent(this.config.projectile, ctx.playerPosition, new THREE.Vector3(0.28, 1.34, 0));
    if (!projectile) return;

    const lowHp = this.hpRatio < 0.45;
    projectile.spec.pattern = lowHp ? 'cone' : 'line';
    projectile.spec.count = lowHp ? 3 : 1;
    projectile.spec.spread = lowHp ? Math.PI * 0.16 : undefined;
    projectile.spec.mode = lowHp ? 'sine' : 'straight';
    projectile.spec.amplitude = lowHp ? 0.18 : undefined;
    projectile.spec.frequency = lowHp ? 8 : undefined;
    events.projectiles.push(projectile);
  }
}
