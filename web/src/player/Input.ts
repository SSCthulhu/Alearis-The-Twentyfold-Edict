import type { Vec2 } from '../core/types';

export type InputAction =
  | 'left'
  | 'right'
  | 'up'
  | 'down'
  | 'jump'
  | 'dash'
  | 'light'
  | 'heavy'
  | 'ultimate'
  | 'defend'
  | 'dice'
  | 'pause';

export interface InputSnapshot {
  move: Vec2;
  moveX: number;
  moveY: number;
  jump: boolean;
  jumpPressed: boolean;
  dash: boolean;
  dashPressed: boolean;
  light: boolean;
  lightPressed: boolean;
  heavy: boolean;
  heavyPressed: boolean;
  ultimate: boolean;
  ultimatePressed: boolean;
  defend: boolean;
  defendPressed: boolean;
  dice: boolean;
  dicePressed: boolean;
  pausePressed: boolean;
}

type InputTarget = Window | HTMLElement;

const KEYBOARD_MAP: Readonly<Record<string, readonly InputAction[]>> = {
  KeyA: ['left'],
  ArrowLeft: ['left'],
  KeyD: ['right'],
  ArrowRight: ['right'],
  KeyW: ['up'],
  ArrowUp: ['up'],
  KeyS: ['down'],
  ArrowDown: ['down'],
  Space: ['jump'],
  ShiftLeft: ['dash'],
  ShiftRight: ['dash'],
  KeyJ: ['light'],
  KeyK: ['heavy'],
  KeyU: ['ultimate'],
  KeyF: ['ultimate'],
  KeyL: ['defend'],
  KeyQ: ['defend'],
  KeyR: ['dice'],
  Escape: ['pause'],
};

const MOUSE_MAP: Readonly<Record<number, InputAction>> = {
  0: 'light',
  2: 'heavy',
};

function addActions(target: Set<InputAction>, actions: readonly InputAction[] | undefined): void {
  if (!actions) return;
  for (const action of actions) target.add(action);
}

function removeActions(target: Set<InputAction>, actions: readonly InputAction[] | undefined): void {
  if (!actions) return;
  for (const action of actions) target.delete(action);
}

export class PlayerInput {
  private readonly held = new Set<InputAction>();
  private previous = new Set<InputAction>();
  private target: InputTarget | null = null;

  attach(target: InputTarget = window): void {
    if (this.target) this.detach();
    this.target = target;
    target.addEventListener('keydown', this.onKeyDown as EventListener);
    target.addEventListener('keyup', this.onKeyUp as EventListener);
    target.addEventListener('mousedown', this.onMouseDown as EventListener);
    target.addEventListener('mouseup', this.onMouseUp as EventListener);
    target.addEventListener('contextmenu', this.onContextMenu as EventListener);
    window.addEventListener('blur', this.onBlur);
  }

  detach(): void {
    if (!this.target) return;
    this.target.removeEventListener('keydown', this.onKeyDown as EventListener);
    this.target.removeEventListener('keyup', this.onKeyUp as EventListener);
    this.target.removeEventListener('mousedown', this.onMouseDown as EventListener);
    this.target.removeEventListener('mouseup', this.onMouseUp as EventListener);
    this.target.removeEventListener('contextmenu', this.onContextMenu as EventListener);
    window.removeEventListener('blur', this.onBlur);
    this.target = null;
    this.held.clear();
    this.previous.clear();
  }

  poll(): InputSnapshot {
    const snapshot = this.createSnapshot();
    this.previous = new Set(this.held);
    return snapshot;
  }

  clearEdges(): void {
    this.previous = new Set(this.held);
  }

  private createSnapshot(): InputSnapshot {
    const moveX = (this.held.has('right') ? 1 : 0) - (this.held.has('left') ? 1 : 0);
    const moveY = (this.held.has('up') ? 1 : 0) - (this.held.has('down') ? 1 : 0);
    return {
      move: { x: moveX, y: moveY },
      moveX,
      moveY,
      jump: this.down('jump'),
      jumpPressed: this.pressed('jump'),
      dash: this.down('dash'),
      dashPressed: this.pressed('dash'),
      light: this.down('light'),
      lightPressed: this.pressed('light'),
      heavy: this.down('heavy'),
      heavyPressed: this.pressed('heavy'),
      ultimate: this.down('ultimate'),
      ultimatePressed: this.pressed('ultimate'),
      defend: this.down('defend'),
      defendPressed: this.pressed('defend'),
      dice: this.down('dice'),
      dicePressed: this.pressed('dice'),
      pausePressed: this.pressed('pause'),
    };
  }

  private down(action: InputAction): boolean {
    return this.held.has(action);
  }

  private pressed(action: InputAction): boolean {
    return this.held.has(action) && !this.previous.has(action);
  }

  private readonly onKeyDown = (event: KeyboardEvent): void => {
    addActions(this.held, KEYBOARD_MAP[event.code]);
    if (event.code === 'Space' || event.code === 'ShiftLeft' || event.code === 'ShiftRight') event.preventDefault();
  };

  private readonly onKeyUp = (event: KeyboardEvent): void => {
    removeActions(this.held, KEYBOARD_MAP[event.code]);
  };

  private readonly onMouseDown = (event: MouseEvent): void => {
    const action = MOUSE_MAP[event.button];
    if (!action) return;
    this.held.add(action);
    event.preventDefault();
  };

  private readonly onMouseUp = (event: MouseEvent): void => {
    const action = MOUSE_MAP[event.button];
    if (!action) return;
    this.held.delete(action);
    event.preventDefault();
  };

  private readonly onContextMenu = (event: Event): void => {
    event.preventDefault();
  };

  private readonly onBlur = (): void => {
    this.held.clear();
    this.previous.clear();
  };
}
