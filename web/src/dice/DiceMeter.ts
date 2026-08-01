import { bus, Events } from '../core/EventBus';
import type { RunState } from '../core/RunState';
import { getCouncilEvent, type CouncilEvent } from './CouncilRegistry';

const METER_FULL = 100;
const KILL_CHARGE = 8;
const ELITE_KILL_CHARGE = 20;
const PERFECT_DODGE_CHARGE = 5;
const DAMAGE_MILESTONE = 50;
const DAMAGE_MILESTONE_CHARGE = 4;
const BOSS_KILL_CHARGE = 20;
const FAST_CLEAR_SECONDS = 30;
const FAST_CLEAR_CHARGE = 15;

export type MeterChargeSource =
  | 'kill'
  | 'elite_kill'
  | 'perfect_dodge'
  | 'damage_dealt'
  | 'boss_kill'
  | 'fast_clear';

export interface ActiveCouncilEvent {
  event: CouncilEvent;
  elapsed: number;
  remaining: number;
}

export interface DiceMeterFullPayload {
  source: MeterChargeSource;
  amount: number;
  meter: number;
}

export interface DiceMeterRollPayload {
  domain: 'dice_meter';
  roll: number;
  diceMin: number;
  diceMax: number;
}

export interface DiceMeterEventPayload {
  event: CouncilEvent;
  roll: number;
  remaining: number;
}

export interface KillOptions {
  elite?: boolean;
}

export class DiceMeterState {
  private current: ActiveCouncilEvent | null = null;

  get activeEvent(): ActiveCouncilEvent | null {
    return this.current;
  }

  tryInvoke(run: RunState): CouncilEvent | null {
    if (!run.spendMeter()) return null;

    const roll = run.roll('dice_meter');
    const event = getCouncilEvent(roll);
    this.current = {
      event,
      elapsed: 0,
      remaining: event.duration,
    };

    bus.emit<DiceMeterRollPayload>(Events.DICE_ROLL, {
      domain: 'dice_meter',
      roll,
      diceMin: run.dice.min,
      diceMax: run.dice.max,
    });
    bus.emit<DiceMeterEventPayload>(Events.DICE_EVENT, {
      event,
      roll,
      remaining: event.duration,
    });

    return event;
  }

  update(dt: number): ActiveCouncilEvent | null {
    if (this.current === null) return null;

    const safeDt = Math.max(0, dt);
    this.current.elapsed += safeDt;
    this.current.remaining = Math.max(0, this.current.event.duration - this.current.elapsed);

    if (this.current.remaining <= 0) {
      this.expire();
      return null;
    }

    return this.current;
  }

  expire(): void {
    this.current = null;
  }
}

export const defaultDiceMeterState = new DiceMeterState();

export function onKill(run: RunState, options: KillOptions = {}): void {
  run.kills += 1;
  chargeDiceMeter(run, options.elite === true ? ELITE_KILL_CHARGE : KILL_CHARGE, options.elite === true ? 'elite_kill' : 'kill');
}

export function onPerfectDodge(run: RunState): void {
  chargeDiceMeter(run, PERFECT_DODGE_CHARGE, 'perfect_dodge');
}

export function onDamageDealt(run: RunState, amount: number): void {
  if (amount <= 0) return;

  run.damageDealt += amount;
  const reachedMilestone = Math.floor(run.damageDealt / DAMAGE_MILESTONE);
  const newMilestones = reachedMilestone - run.damageMilestoneCursor;
  if (newMilestones <= 0) return;

  run.damageMilestoneCursor = reachedMilestone;
  chargeDiceMeter(run, newMilestones * DAMAGE_MILESTONE_CHARGE, 'damage_dealt');
}

export function onBossKill(run: RunState): void {
  chargeDiceMeter(run, BOSS_KILL_CHARGE, 'boss_kill');
}

export function onFastClear(run: RunState, clearTimeSeconds: number): void {
  if (clearTimeSeconds <= FAST_CLEAR_SECONDS) {
    chargeDiceMeter(run, FAST_CLEAR_CHARGE, 'fast_clear');
  }
}

export function tryInvoke(run: RunState): CouncilEvent | null {
  return defaultDiceMeterState.tryInvoke(run);
}

export function update(dt: number): ActiveCouncilEvent | null {
  return defaultDiceMeterState.update(dt);
}

export function expire(): void {
  defaultDiceMeterState.expire();
}

export function getActiveEvent(): ActiveCouncilEvent | null {
  return defaultDiceMeterState.activeEvent;
}

export function chargeDiceMeter(
  run: RunState,
  amount: number,
  source: MeterChargeSource,
): void {
  if (amount <= 0) return;

  const before = run.diceMeter;
  run.chargeMeter(amount);

  if (before < METER_FULL && run.diceMeter >= METER_FULL) {
    bus.emit<DiceMeterFullPayload>(Events.DICE_METER_FULL, {
      source,
      amount,
      meter: run.diceMeter,
    });
  }
}
