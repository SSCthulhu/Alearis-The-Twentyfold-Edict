export type StatusEffectId = 'chill' | 'voidMarked' | 'shocked' | 'bleed';

export interface StatusEffectSpec {
  id: StatusEffectId;
  duration: number;
  stacks?: number;
  sourceId?: string;
}

export interface StatusTick {
  id: StatusEffectId;
  amount: number;
  sourceId?: string;
}

export interface StatusModifiers {
  movementScale: number;
  damageTakenScale: number;
  outgoingDamageScale: number;
  stunned: boolean;
  visibleTags: readonly StatusEffectId[];
}

export interface StatusHostHooks {
  onStatusApplied?: (status: ActiveStatusEffect) => void;
  onStatusExpired?: (status: ActiveStatusEffect) => void;
  onStatusTickDamage?: (tick: StatusTick) => void;
}

export interface ActiveStatusEffect {
  id: StatusEffectId;
  duration: number;
  remaining: number;
  stacks: number;
  sourceId?: string;
  tickTimer: number;
}

interface StatusDefinition {
  movementScale: number;
  damageTakenScale: number;
  outgoingDamageScale: number;
  tickEvery: number;
  tickDamage: number;
  maxStacks: number;
  stunPulseEvery: number;
  stunPulseDuration: number;
}

const STATUS_DEFINITIONS: Record<StatusEffectId, StatusDefinition> = {
  chill: {
    movementScale: 0.62,
    damageTakenScale: 1,
    outgoingDamageScale: 1,
    tickEvery: 0,
    tickDamage: 0,
    maxStacks: 3,
    stunPulseEvery: 0,
    stunPulseDuration: 0,
  },
  voidMarked: {
    movementScale: 1,
    damageTakenScale: 1.18,
    outgoingDamageScale: 1,
    tickEvery: 0,
    tickDamage: 0,
    maxStacks: 1,
    stunPulseEvery: 0,
    stunPulseDuration: 0,
  },
  shocked: {
    movementScale: 0.9,
    damageTakenScale: 1.08,
    outgoingDamageScale: 0.92,
    tickEvery: 0.75,
    tickDamage: 2,
    maxStacks: 2,
    stunPulseEvery: 1.15,
    stunPulseDuration: 0.12,
  },
  bleed: {
    movementScale: 1,
    damageTakenScale: 1,
    outgoingDamageScale: 1,
    tickEvery: 0.5,
    tickDamage: 3,
    maxStacks: 5,
    stunPulseEvery: 0,
    stunPulseDuration: 0,
  },
};

export class StatusEffectController {
  private readonly effects = new Map<StatusEffectId, ActiveStatusEffect>();
  private readonly hooks: StatusHostHooks;
  private shockStunRemaining = 0;
  private shockPulseTimer = 0;

  constructor(hooks: StatusHostHooks = {}) {
    this.hooks = hooks;
  }

  apply(spec: StatusEffectSpec): ActiveStatusEffect {
    const definition = STATUS_DEFINITIONS[spec.id];
    const existing = this.effects.get(spec.id);
    if (existing) {
      existing.duration = Math.max(existing.duration, spec.duration);
      existing.remaining = Math.max(existing.remaining, spec.duration);
      existing.stacks = Math.min(definition.maxStacks, existing.stacks + (spec.stacks ?? 1));
      existing.sourceId = spec.sourceId ?? existing.sourceId;
      this.hooks.onStatusApplied?.(existing);
      return existing;
    }

    const status: ActiveStatusEffect = {
      id: spec.id,
      duration: spec.duration,
      remaining: spec.duration,
      stacks: Math.min(definition.maxStacks, spec.stacks ?? 1),
      sourceId: spec.sourceId,
      tickTimer: definition.tickEvery,
    };
    this.effects.set(spec.id, status);
    this.hooks.onStatusApplied?.(status);
    return status;
  }

  remove(id: StatusEffectId): void {
    const status = this.effects.get(id);
    if (!status) return;
    this.effects.delete(id);
    this.hooks.onStatusExpired?.(status);
  }

  clear(): void {
    for (const id of Array.from(this.effects.keys())) this.remove(id);
    this.shockStunRemaining = 0;
    this.shockPulseTimer = 0;
  }

  has(id: StatusEffectId): boolean {
    return this.effects.has(id);
  }

  get(id: StatusEffectId): ActiveStatusEffect | undefined {
    return this.effects.get(id);
  }

  update(dt: number): StatusTick[] {
    const ticks: StatusTick[] = [];
    const expired: StatusEffectId[] = [];

    this.shockStunRemaining = Math.max(0, this.shockStunRemaining - dt);

    for (const status of this.effects.values()) {
      const definition = STATUS_DEFINITIONS[status.id];
      status.remaining -= dt;

      if (definition.tickEvery > 0) {
        status.tickTimer -= dt;
        while (status.tickTimer <= 0 && status.remaining > 0) {
          status.tickTimer += definition.tickEvery;
          const tick = {
            id: status.id,
            amount: definition.tickDamage * status.stacks,
            sourceId: status.sourceId,
          };
          ticks.push(tick);
          this.hooks.onStatusTickDamage?.(tick);
        }
      }

      if (status.id === 'shocked') {
        this.shockPulseTimer -= dt;
        if (this.shockPulseTimer <= 0) {
          this.shockPulseTimer = definition.stunPulseEvery;
          this.shockStunRemaining = Math.max(this.shockStunRemaining, definition.stunPulseDuration);
        }
      }

      if (status.remaining <= 0) expired.push(status.id);
    }

    for (const id of expired) this.remove(id);
    return ticks;
  }

  modifiers(): StatusModifiers {
    let movementScale = 1;
    let damageTakenScale = 1;
    let outgoingDamageScale = 1;
    const visibleTags: StatusEffectId[] = [];

    for (const status of this.effects.values()) {
      const definition = STATUS_DEFINITIONS[status.id];
      const stackWeight = 1 + (status.stacks - 1) * 0.18;
      movementScale *= Math.pow(definition.movementScale, stackWeight);
      damageTakenScale *= Math.pow(definition.damageTakenScale, stackWeight);
      outgoingDamageScale *= Math.pow(definition.outgoingDamageScale, stackWeight);
      visibleTags.push(status.id);
    }

    return {
      movementScale,
      damageTakenScale,
      outgoingDamageScale,
      stunned: this.shockStunRemaining > 0,
      visibleTags,
    };
  }

  active(): ActiveStatusEffect[] {
    return Array.from(this.effects.values()).map((status) => ({ ...status }));
  }
}
