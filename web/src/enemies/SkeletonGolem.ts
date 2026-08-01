import * as THREE from 'three';
import { EnemyBase, type EnemyAiContext, type EnemyFrameEvents } from './EnemyBase';
import type { FigureColors } from '../actors/ProceduralFigure';

export class SkeletonGolem extends EnemyBase {
  constructor(position = new THREE.Vector3(), colors: FigureColors = {}) {
    super('skeletonGolem', position, colors);
  }

  protected override appendAttackEvents(ctx: EnemyAiContext, events: EnemyFrameEvents): void {
    events.melee.push({
      type: 'melee',
      enemy: this,
      origin: this.root.position.clone().add(new THREE.Vector3(this.facing * 0.62, 1.0, 0)),
      facing: this.facing,
      range: this.config.meleeRange,
      arc: this.config.meleeArc,
      damage: this.config.meleeDamage,
      knockback: 2.2,
      telegraphTime: this.config.windup,
    });

    if (!this.config.projectile || ctx.rng() > 0.55) return;
    const quake = this.createProjectileEvent(this.config.projectile, ctx.playerPosition, new THREE.Vector3(0.25, 0.65, 0));
    if (!quake) return;
    quake.spec.pattern = 'arc';
    quake.spec.arc = Math.PI * 0.8;
    quake.spec.count = 5;
    quake.spec.speed = 4.2;
    quake.spec.mode = 'straight';
    events.projectiles.push(quake);
  }
}
