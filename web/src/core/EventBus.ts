type Handler<T> = (payload: T) => void;

/** Tiny typed pub/sub used across systems without circular deps. */
export class EventBus {
  private readonly map = new Map<string, Set<Handler<unknown>>>();

  on<T>(event: string, handler: Handler<T>): () => void {
    let set = this.map.get(event);
    if (!set) {
      set = new Set();
      this.map.set(event, set);
    }
    set.add(handler as Handler<unknown>);
    return () => set!.delete(handler as Handler<unknown>);
  }

  emit<T>(event: string, payload: T): void {
    const set = this.map.get(event);
    if (!set) return;
    for (const h of set) h(payload);
  }

  clear(): void {
    this.map.clear();
  }
}

export const bus = new EventBus();

export const Events = {
  DAMAGE: 'damage',
  KILL: 'kill',
  PERFECT_DODGE: 'perfect_dodge',
  DICE_ROLL: 'dice_roll',
  DICE_METER_FULL: 'dice_meter_full',
  DICE_EVENT: 'dice_event',
  FLOOR_CLEARED: 'floor_cleared',
  MODIFIER_CHOSEN: 'modifier_chosen',
  RELIC_CHOSEN: 'relic_chosen',
  BOSS_PHASE: 'boss_phase',
  ASCENSION_PICKUP: 'ascension_pickup',
  ASCENSION_DROP: 'ascension_drop',
  ASCENSION_DELIVERED: 'ascension_delivered',
  DPS_WINDOW_START: 'dps_window_start',
  DPS_WINDOW_END: 'dps_window_end',
  SCREEN_SHAKE: 'screen_shake',
  PHASE_CHANGE: 'phase_change',
  PLAYER_DEATH: 'player_death',
  RUN_VICTORY: 'run_victory',
} as const;
