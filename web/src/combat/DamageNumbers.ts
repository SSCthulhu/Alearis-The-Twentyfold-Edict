import * as THREE from 'three';

export interface DamageNumberOptions {
  color?: string;
  crit?: boolean;
  heal?: boolean;
  scale?: number;
  lifetime?: number;
  drift?: THREE.Vector3;
}

interface DamageNumberItem {
  sprite: THREE.Sprite;
  velocity: THREE.Vector3;
  age: number;
  lifetime: number;
  baseScale: number;
  active: boolean;
}

function makeLabelTexture(text: string, color: string, crit: boolean, heal: boolean): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = crit ? 192 : 144;
  canvas.height = 96;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Canvas 2D context is required for damage numbers.');

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.font = `${crit ? 800 : 700} ${crit ? 42 : 34}px system-ui, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.lineJoin = 'round';
  ctx.lineWidth = crit ? 9 : 7;
  ctx.strokeStyle = heal ? '#183420' : '#18101f';
  ctx.strokeText(text, canvas.width * 0.5, canvas.height * 0.52);
  ctx.fillStyle = color;
  ctx.fillText(text, canvas.width * 0.5, canvas.height * 0.52);

  if (crit) {
    ctx.strokeStyle = '#18101f';
    ctx.fillStyle = '#fff3a8';
    for (const point of [
      [24, 18],
      [canvas.width - 24, 22],
      [canvas.width - 32, canvas.height - 20],
    ]) {
      ctx.beginPath();
      ctx.moveTo(point[0], point[1] - 8);
      ctx.lineTo(point[0] + 5, point[1] - 2);
      ctx.lineTo(point[0] + 12, point[1]);
      ctx.lineTo(point[0] + 5, point[1] + 3);
      ctx.lineTo(point[0], point[1] + 10);
      ctx.lineTo(point[0] - 4, point[1] + 3);
      ctx.lineTo(point[0] - 12, point[1]);
      ctx.lineTo(point[0] - 4, point[1] - 2);
      ctx.closePath();
      ctx.stroke();
      ctx.fill();
    }
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.magFilter = THREE.NearestFilter;
  texture.minFilter = THREE.LinearFilter;
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

export class DamageNumberSystem {
  readonly root = new THREE.Group();
  private readonly pool: DamageNumberItem[] = [];
  private cursor = 0;

  constructor(capacity = 64) {
    this.root.name = 'damage_number_system';
    for (let i = 0; i < capacity; i++) this.pool.push(this.createItem());
  }

  spawn(amount: number | string, position: THREE.Vector3, options: DamageNumberOptions = {}): THREE.Sprite {
    const item = this.pool[this.cursor]!;
    this.cursor = (this.cursor + 1) % this.pool.length;

    const text = typeof amount === 'number' ? Math.round(amount).toString() : amount;
    const color = options.color ?? (options.heal ? '#77ff9b' : options.crit ? '#ffe066' : '#ffffff');
    const oldMap = item.sprite.material.map;
    if (oldMap) oldMap.dispose();
    item.sprite.material.map = makeLabelTexture(text, color, options.crit ?? false, options.heal ?? false);
    item.sprite.material.opacity = 1;
    item.sprite.material.needsUpdate = true;
    item.sprite.position.copy(position);
    item.sprite.visible = true;

    item.age = 0;
    item.lifetime = options.lifetime ?? (options.crit ? 0.95 : 0.75);
    item.baseScale = options.scale ?? (options.crit ? 0.72 : 0.52);
    item.velocity.copy(options.drift ?? new THREE.Vector3(0.05, 1.25, 0));
    item.velocity.x += (this.cursor % 5 - 2) * 0.08;
    item.active = true;
    return item.sprite;
  }

  update(dt: number): void {
    for (const item of this.pool) {
      if (!item.active) continue;
      item.age += dt;
      const t = item.age / item.lifetime;
      if (t >= 1) {
        item.active = false;
        item.sprite.visible = false;
        continue;
      }

      item.velocity.y -= dt * 0.55;
      item.sprite.position.addScaledVector(item.velocity, dt);
      const pop = t < 0.18 ? THREE.MathUtils.lerp(0.2, 1.15, t / 0.18) : THREE.MathUtils.lerp(1.15, 0.82, t);
      item.sprite.scale.setScalar(item.baseScale * pop);
      item.sprite.material.opacity = t > 0.65 ? THREE.MathUtils.lerp(1, 0, (t - 0.65) / 0.35) : 1;
    }
  }

  dispose(): void {
    for (const item of this.pool) {
      item.sprite.material.map?.dispose();
      item.sprite.material.dispose();
    }
  }

  private createItem(): DamageNumberItem {
    const material = new THREE.SpriteMaterial({
      transparent: true,
      depthWrite: false,
      depthTest: true,
      sizeAttenuation: true,
    });
    const sprite = new THREE.Sprite(material);
    sprite.name = 'damage_number';
    sprite.visible = false;
    this.root.add(sprite);
    return {
      sprite,
      velocity: new THREE.Vector3(),
      age: 0,
      lifetime: 1,
      baseScale: 1,
      active: false,
    };
  }
}
