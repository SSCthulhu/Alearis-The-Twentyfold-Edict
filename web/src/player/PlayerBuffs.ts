export type PlayerBuffId =
  | 'knight_shield'
  | 'rogue_evasion'
  | 'mage_locked_focus'
  | 'perfect_dodge'
  | 'ultimate_empower';

export interface PlayerBuff {
  id: PlayerBuffId;
  duration: number;
  damageReduction: number;
  moveSpeedMult: number;
  attackSpeedMult: number;
  dodgeChance: number;
  source: string;
}

export interface PlayerBuffSpec {
  id: PlayerBuffId;
  duration: number;
  damageReduction?: number;
  moveSpeedMult?: number;
  attackSpeedMult?: number;
  dodgeChance?: number;
  source?: string;
}

export class PlayerBuffs {
  private readonly buffs = new Map<PlayerBuffId, PlayerBuff>();

  apply(spec: PlayerBuffSpec): void {
    this.buffs.set(spec.id, {
      id: spec.id,
      duration: spec.duration,
      damageReduction: spec.damageReduction ?? 0,
      moveSpeedMult: spec.moveSpeedMult ?? 1,
      attackSpeedMult: spec.attackSpeedMult ?? 1,
      dodgeChance: spec.dodgeChance ?? 0,
      source: spec.source ?? 'player',
    });
  }

  update(dt: number): void {
    for (const [id, buff] of this.buffs) {
      buff.duration -= dt;
      if (buff.duration <= 0) this.buffs.delete(id);
    }
  }

  clear(): void {
    this.buffs.clear();
  }

  has(id: PlayerBuffId): boolean {
    return this.buffs.has(id);
  }

  remaining(id: PlayerBuffId): number {
    return this.buffs.get(id)?.duration ?? 0;
  }

  damageTakenMultiplier(): number {
    let multiplier = 1;
    for (const buff of this.buffs.values()) multiplier *= 1 - buff.damageReduction;
    return Math.max(0.05, multiplier);
  }

  moveSpeedMultiplier(): number {
    let multiplier = 1;
    for (const buff of this.buffs.values()) multiplier *= buff.moveSpeedMult;
    return multiplier;
  }

  attackSpeedMultiplier(): number {
    let multiplier = 1;
    for (const buff of this.buffs.values()) multiplier *= buff.attackSpeedMult;
    return multiplier;
  }

  dodgeChance(): number {
    let chance = 0;
    for (const buff of this.buffs.values()) chance += buff.dodgeChance;
    return Math.min(0.85, chance);
  }

  snapshot(): readonly PlayerBuff[] {
    return Array.from(this.buffs.values()).map((buff) => ({ ...buff }));
  }
}
