import type { RunState } from '../core/RunState';

const MIN_MULTIPLIER = 0.1;

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

export class RelicEffects {
  private readonly run: RunState;
  private dpsWindowBonusReady = false;

  constructor(run: RunState) {
    this.run = run;
  }

  onFloorStart(): void {
    this.dpsWindowBonusReady = false;
  }

  onDpsWindowStart(): void {
    this.dpsWindowBonusReady = this.sumParam('dpsWindowBonusSeconds') > 0;
  }

  getDamageMultiplier(): number {
    return this.multiplierFromBonus('damageMultBonus');
  }

  getMoveSpeedMult(): number {
    return this.multiplierFromBonus('moveSpeedMultBonus');
  }

  getDashChargesBonus(): number {
    return Math.max(0, Math.trunc(this.sumParam('dashChargesBonus')));
  }

  getPerfectWindowBonus(): number {
    return this.sumParam('perfectWindowBonus');
  }

  getDpsWindowBonus(): number {
    if (!this.dpsWindowBonusReady) return 0;
    this.dpsWindowBonusReady = false;
    return Math.max(0, this.sumParam('dpsWindowBonusSeconds'));
  }

  getMeterChargeMult(): number {
    return this.multiplierFromBonus('meterChargeMultBonus');
  }

  getOrbChargeRateMult(): number {
    return this.multiplierFromBonus('orbChargeRateMultBonus');
  }

  getCritChanceBonus(): number {
    return clamp(this.sumParam('critChanceBonus'), 0, 1);
  }

  getHealOnKill(): number {
    return Math.max(0, this.sumParam('healOnKill'));
  }

  getIncomingDamageMultiplier(): number {
    return this.multiplierFromBonus('incomingDamageMultBonus');
  }

  getOrbCarryMoveSpeedMult(): number {
    return this.multiplierFromBonus('orbCarryMoveSpeedMultBonus');
  }

  getVictoryRollBonus(): number {
    return Math.trunc(this.sumParam('victoryRollBonus'));
  }

  getLowRollFloor(): number {
    return Math.max(0, Math.trunc(this.maxParam('lowRollFloor')));
  }

  getBonusOfferCount(): number {
    return Math.max(0, Math.trunc(this.sumParam('bonusOfferCount')));
  }

  hasEffect(effectId: string): boolean {
    return this.run.hasRelicEffect(effectId);
  }

  relicParam(effectId: string, key: string, fallback = 0): number {
    return this.run.relicParam(effectId, key, fallback);
  }

  private multiplierFromBonus(key: string): number {
    return Math.max(MIN_MULTIPLIER, 1 + this.sumParam(key));
  }

  private sumParam(key: string): number {
    let total = 0;
    for (const relic of this.run.relics) {
      const value = relic.params[key];
      if (value !== undefined && Number.isFinite(value)) {
        total += value;
      }
    }
    return total;
  }

  private maxParam(key: string): number {
    let current = 0;
    for (const relic of this.run.relics) {
      const value = relic.params[key];
      if (value !== undefined && Number.isFinite(value)) {
        current = Math.max(current, value);
      }
    }
    return current;
  }
}
