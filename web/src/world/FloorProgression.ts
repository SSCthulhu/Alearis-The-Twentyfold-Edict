import { bus, Events } from '../core/EventBus';
import type { RunState } from '../core/RunState';
import type { GamePhase, WorldId } from '../core/types';

export type FloorProgressionStep =
  | 'combat'
  | 'chest'
  | 'modifier_choice'
  | 'victory_roll'
  | 'relic_choice'
  | 'next_unlocked'
  | 'victory';

export interface FloorClearedPayload {
  world: WorldId;
  floor: number;
  bossFloor: boolean;
}

export interface FloorAdvanceResult {
  previousWorld: WorldId;
  previousFloor: number;
  world: WorldId;
  floor: number;
  changedWorld: boolean;
  finalVictory: boolean;
}

export class FloorProgression {
  readonly run: RunState;
  step: FloorProgressionStep = 'combat';
  chestClaimed = false;
  modifierChosen = false;
  nextUnlocked = false;

  constructor(run: RunState) {
    this.run = run;
  }

  beginFloor(): void {
    this.chestClaimed = false;
    this.modifierChosen = false;
    this.nextUnlocked = false;
    this.step = 'combat';
    this.run.floorElapsed = 0;
    this.setPhase(this.run.isBossFloor() ? 'boss_intro' : 'floor_intro');
  }

  beginCombat(): void {
    this.step = 'combat';
    this.setPhase(this.run.isBossFloor() ? 'boss_fight' : 'combat');
  }

  markCombatCleared(): FloorProgressionStep {
    const bossFloor = this.run.isBossFloor();
    bus.emit<FloorClearedPayload>(Events.FLOOR_CLEARED, {
      world: this.run.world,
      floor: this.run.floor,
      bossFloor,
    });

    if (bossFloor) {
      this.step = 'victory_roll';
      this.setPhase('victory_roll');
      return this.step;
    }

    this.step = 'chest';
    this.setPhase('chest');
    return this.step;
  }

  claimChest(): FloorProgressionStep {
    this.chestClaimed = true;
    if (this.run.isBossFloor()) {
      this.step = 'victory_roll';
      this.setPhase('victory_roll');
      return this.step;
    }

    this.step = 'modifier_choice';
    this.setPhase('modifier_choice');
    return this.step;
  }

  completeModifierChoice(): FloorAdvanceResult {
    this.modifierChosen = true;
    return this.unlockNextFloor();
  }

  completeVictoryRoll(): FloorProgressionStep {
    if (this.run.world === 4) {
      this.step = 'victory';
      this.setPhase('victory');
      return this.step;
    }

    this.step = 'relic_choice';
    this.setPhase('relic_choice');
    return this.step;
  }

  completeRelicChoice(): FloorAdvanceResult {
    return this.unlockNextFloor();
  }

  unlockNextFloor(): FloorAdvanceResult {
    const previousWorld = this.run.world;
    const previousFloor = this.run.floor;

    if (previousWorld === 4) {
      this.nextUnlocked = false;
      this.step = 'victory';
      this.setPhase('victory');
      return {
        previousWorld,
        previousFloor,
        world: this.run.world,
        floor: this.run.floor,
        changedWorld: false,
        finalVictory: true,
      };
    }

    this.run.advanceFloor();
    const changedWorld = this.run.world !== previousWorld;
    if (changedWorld) this.run.resetWorldModifiers();

    this.nextUnlocked = true;
    this.step = 'next_unlocked';
    this.setPhase(changedWorld ? 'world_transition' : 'floor_intro');

    return {
      previousWorld,
      previousFloor,
      world: this.run.world,
      floor: this.run.floor,
      changedWorld,
      finalVictory: false,
    };
  }

  private setPhase(phase: GamePhase): void {
    this.run.phase = phase;
  }
}
