import * as THREE from 'three';
import type { ArenaPlatform } from '../world/ArenaBuilder';

/**
 * Pooled hard-edged blob shadows that ground every figure against the arena.
 * Each shadow is a camera-facing squashed disc pinned to the platform top
 * directly beneath the figure — a cel-friendly contact shadow with zero
 * shadow-map cost. Shadows shrink and fade as the figure rises, and vanish
 * entirely over pits.
 */

/** Hexagonal rather than round: a faceted contact patch reads as drawn, not blurred. */
const SHADOW_GEO = new THREE.CircleGeometry(1, 8);
/** Height above ground at which the shadow fades out completely. */
const MAX_DROP = 7;
/** Hard-edge cel shadow opacity at ground contact. */
const BASE_OPACITY = 0.42;
/** Just in front of platform front lips (depth 2.2 + lip 0.16 → face ~1.22). */
const SHADOW_Z = 1.26;
/** Neutral black shadows go muddy against a saturated palette; tint toward world ink. */
const DEFAULT_TINT = '#16283c';

export class ContactShadows {
  readonly root = new THREE.Group();
  private readonly items: THREE.Mesh<THREE.BufferGeometry, THREE.MeshBasicMaterial>[] = [];
  private cursor = 0;

  constructor(capacity = 24) {
    this.root.name = 'contact_shadows';
    for (let i = 0; i < capacity; i++) {
      const mesh = new THREE.Mesh(
        SHADOW_GEO,
        new THREE.MeshBasicMaterial({
          color: DEFAULT_TINT,
          transparent: true,
          opacity: BASE_OPACITY,
          depthWrite: false,
        }),
      );
      mesh.name = `contact_shadow_${i}`;
      mesh.visible = false;
      mesh.renderOrder = 6;
      mesh.rotation.z = Math.PI / 8;
      this.root.add(mesh);
      this.items.push(mesh);
    }
  }

  /** Re-tints the pool when the world palette changes. */
  setTint(color: THREE.ColorRepresentation): void {
    for (const mesh of this.items) mesh.material.color.set(color);
  }

  beginFrame(): void {
    this.cursor = 0;
  }

  /** Places the next pooled shadow on the platform below (x, y); no-op when airborne over a pit. */
  place(x: number, y: number, radius: number, platforms: readonly ArenaPlatform[]): void {
    if (this.cursor >= this.items.length) return;

    let groundY = Number.NEGATIVE_INFINITY;
    for (const platform of platforms) {
      if (x < platform.aabb.x - radius * 0.5 || x > platform.aabb.x + platform.aabb.w + radius * 0.5) continue;
      if (platform.topY > y + 0.25 || platform.topY < groundY) continue;
      groundY = platform.topY;
    }
    if (groundY === Number.NEGATIVE_INFINITY) return;

    const height = Math.max(0, y - groundY);
    if (height > MAX_DROP) return;
    const contact = 1 - height / MAX_DROP;

    const mesh = this.items[this.cursor]!;
    this.cursor += 1;
    mesh.visible = true;
    mesh.position.set(x, groundY + 0.045, SHADOW_Z);
    const spread = radius * (0.55 + contact * 0.45);
    mesh.scale.set(spread, spread * 0.26, 1);
    mesh.material.opacity = BASE_OPACITY * (0.3 + contact * 0.7);
  }

  endFrame(): void {
    for (let i = this.cursor; i < this.items.length; i++) this.items[i]!.visible = false;
  }
}
