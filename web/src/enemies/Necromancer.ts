import * as THREE from 'three';
import { EnemyBase, type EnemyAiContext, type EnemyFrameEvents } from './EnemyBase';
import type { FigureColors } from '../actors/ProceduralFigure';

export class Necromancer extends EnemyBase {
  private castCount = 0;

  constructor(position = new THREE.Vector3(), colors: FigureColors = {}) {
    super('necromancer', position, colors);
  }

  protected override appendAttackEvents(ctx: EnemyAiContext, events: EnemyFrameEvents): void {
    this.castCount++;
    if (this.config.projectile) {
      const projectile = this.createProjectileEvent(this.config.projectile, ctx.playerPosition, new THREE.Vector3(0.35, 1.42, 0));
      if (projectile) events.projectiles.push(projectile);
    }

    if (this.castCount % 2 !== 0 || !this.config.summonKind) return;

    const count = this.config.summonCount ?? 1;
    const platform = this.currentPlatform;
    for (let i = 0; i < count; i++) {
      const side = i % 2 === 0 ? -1 : 1;
      const jitter = (ctx.rng() - 0.5) * 0.5;
      const x = this.root.position.x + side * (0.85 + i * 0.25) + jitter;
      const clampedX = platform ? THREE.MathUtils.clamp(x, platform.xMin + 0.65, platform.xMax - 0.65) : x;
      const y = platform ? platform.y : this.root.position.y;
      this.emitSummon(events, this.config.summonKind, new THREE.Vector3(clampedX, y, this.root.position.z));
    }
  }
}
