export type PlayerDebuffId = 'bleed' | 'burn' | 'shock' | 'slow' | 'frailty';

export interface PlayerDebuff {
  id: PlayerDebuffId;
  duration: number;
  moveSpeedMult: number;
  damageTakenMult: number;
  tickDamage: number;
  tickInterval: number;
  tickTimer: number;
  source: string;
}

export interface PlayerDebuffSpec {
  id: PlayerDebuffId;
  duration: number;
  moveSpeedMult?: number;
  damageTakenMult?: number;
  tickDamage?: number;
  tickInterval?: number;
  source?: string;
}

export interface PlayerDebuffTick {
  id: PlayerDebuffId;
  amount: number;
  source: string;
}

export class PlayerDebuffs {
  private readonly debuffs = new Map<PlayerDebuffId, PlayerDebuff>();

  apply(spec: PlayerDebuffSpec): void {
    this.debuffs.set(spec.id, {
      id: spec.id,
      duration: spec.duration,
      moveSpeedMult: spec.moveSpeedMult ?? 1,
      damageTakenMult: spec.damageTakenMult ?? 1,
      tickDamage: spec.tickDamage ?? 0,
      tickInterval: spec.tickInterval ?? 1,
      tickTimer: spec.tickInterval ?? 1,
      source: spec.source ?? 'enemy',
    });
  }

  update(dt: number): PlayerDebuffTick[] {
    const ticks: PlayerDebuffTick[] = [];
    for (const [id, debuff] of this.debuffs) {
      debuff.duration -= dt;
      if (debuff.tickDamage > 0) {
        debuff.tickTimer -= dt;
        while (debuff.tickTimer <= 0 && debuff.duration > 0) {
          ticks.push({ id, amount: debuff.tickDamage, source: debuff.source });
          debuff.tickTimer += debuff.tickInterval;
        }
      }
      if (debuff.duration <= 0) this.debuffs.delete(id);
    }
    return ticks;
  }

  clear(): void {
    this.debuffs.clear();
  }

  has(id: PlayerDebuffId): boolean {
    return this.debuffs.has(id);
  }

  moveSpeedMultiplier(): number {
    let multiplier = 1;
    for (const debuff of this.debuffs.values()) multiplier *= debuff.moveSpeedMult;
    return multiplier;
  }

  damageTakenMultiplier(): number {
    let multiplier = 1;
    for (const debuff of this.debuffs.values()) multiplier *= debuff.damageTakenMult;
    return multiplier;
  }

  snapshot(): readonly PlayerDebuff[] {
    return Array.from(this.debuffs.values()).map((debuff) => ({ ...debuff }));
  }
}
