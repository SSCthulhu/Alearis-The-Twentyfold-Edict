/** Hard clamp for the D20 probability window. */
export const DICE_ABS_MIN = 1;
export const DICE_ABS_MAX = 20;

export class DiceRange {
  min: number;
  max: number;

  constructor(min = 10, max = 10) {
    this.min = min;
    this.max = max;
    this.clamp();
  }

  clamp(): void {
    this.min = Math.max(DICE_ABS_MIN, Math.min(DICE_ABS_MAX, Math.floor(this.min)));
    this.max = Math.max(DICE_ABS_MIN, Math.min(DICE_ABS_MAX, Math.floor(this.max)));
    if (this.min > this.max) {
      const mid = this.min;
      this.min = this.max;
      this.max = mid;
    }
  }

  /** Apply a floor-modifier delta. Positive widens upward; negative widens downward. */
  applyDelta(delta: number): void {
    if (delta > 0) {
      this.max = Math.min(DICE_ABS_MAX, this.max + delta);
    } else if (delta < 0) {
      this.min = Math.max(DICE_ABS_MIN, this.min + delta);
    }
    this.clamp();
  }

  width(): number {
    return this.max - this.min;
  }

  contains(n: number): boolean {
    return n >= this.min && n <= this.max;
  }

  copy(): DiceRange {
    return new DiceRange(this.min, this.max);
  }

  toString(): string {
    return `${this.min}–${this.max}`;
  }
}
