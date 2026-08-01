import { bus, Events } from '../core/EventBus';
import type { DamageInfo } from '../core/types';
import type { PlayerBuffs } from './PlayerBuffs';
import type { PlayerDebuffs } from './PlayerDebuffs';

export interface PlayerDamageOptions {
  invulnerable?: boolean;
  allowDodge?: boolean;
  rng?: () => number;
}

export interface PlayerDamageResult {
  applied: number;
  ignored: boolean;
  dodged: boolean;
  killed: boolean;
}

export class PlayerHealth {
  readonly maxHp: number;
  hp: number;
  private readonly buffs: PlayerBuffs;
  private readonly debuffs: PlayerDebuffs;

  constructor(buffs: PlayerBuffs, debuffs: PlayerDebuffs, maxHp = 100) {
    this.buffs = buffs;
    this.debuffs = debuffs;
    this.maxHp = maxHp;
    this.hp = maxHp;
  }

  get alive(): boolean {
    return this.hp > 0;
  }

  get ratio(): number {
    return this.maxHp <= 0 ? 0 : this.hp / this.maxHp;
  }

  heal(amount: number): number {
    if (amount <= 0 || !this.alive) return 0;
    const before = this.hp;
    this.hp = Math.min(this.maxHp, this.hp + amount);
    return this.hp - before;
  }

  takeDamage(info: DamageInfo, options: PlayerDamageOptions = {}): PlayerDamageResult {
    if (!this.alive || options.invulnerable) {
      return { applied: 0, ignored: true, dodged: false, killed: false };
    }

    if (options.allowDodge && options.rng && options.rng() < this.buffs.dodgeChance()) {
      bus.emit(Events.PERFECT_DODGE, { source: info.source, evaded: true });
      return { applied: 0, ignored: true, dodged: true, killed: false };
    }

    const critMult = info.crit ? 1.5 : 1;
    const amount = Math.max(
      0,
      info.amount * critMult * this.buffs.damageTakenMultiplier() * this.debuffs.damageTakenMultiplier(),
    );
    this.hp = Math.max(0, this.hp - amount);
    const killed = this.hp <= 0;
    if (killed) bus.emit(Events.PLAYER_DEATH, { source: info.source });
    return { applied: amount, ignored: amount <= 0, dodged: false, killed };
  }

  kill(source: DamageInfo['source'] = 'system'): void {
    if (!this.alive) return;
    this.hp = 0;
    bus.emit(Events.PLAYER_DEATH, { source });
  }

  reset(): void {
    this.hp = this.maxHp;
  }
}
