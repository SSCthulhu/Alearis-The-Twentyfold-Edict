/** Runtime performance budgets — a beautiful stuttering game is a failed game. */
export class PerfBudget {
  targetFps = 60;
  maxPixelRatio = 2;
  minPixelRatio = 1;
  pixelRatio = Math.min(window.devicePixelRatio || 1, 2);

  projectileBudget = 220;
  debrisBudget = 160;
  sparkleBudget = 120;
  enemyDrawBudget = 24;

  private frameTimes: number[] = [];
  private adaptiveCooldown = 0;

  observeFrame(dt: number): void {
    this.frameTimes.push(dt);
    if (this.frameTimes.length > 45) this.frameTimes.shift();
    this.adaptiveCooldown -= dt;
    if (this.adaptiveCooldown > 0) return;

    const avg = this.frameTimes.reduce((a, b) => a + b, 0) / this.frameTimes.length;
    const fps = 1 / Math.max(avg, 0.0001);
    if (fps < 50 && this.pixelRatio > this.minPixelRatio) {
      this.pixelRatio = Math.max(this.minPixelRatio, this.pixelRatio - 0.25);
      this.projectileBudget = Math.max(80, this.projectileBudget - 20);
      this.debrisBudget = Math.max(40, this.debrisBudget - 15);
      this.adaptiveCooldown = 1.2;
    } else if (fps > 58 && this.pixelRatio < this.maxPixelRatio) {
      this.pixelRatio = Math.min(this.maxPixelRatio, this.pixelRatio + 0.15);
      this.projectileBudget = Math.min(220, this.projectileBudget + 10);
      this.adaptiveCooldown = 2.0;
    }
  }

  lodScale(distance: number): number {
    if (distance < 18) return 1;
    if (distance < 35) return 0.7;
    return 0.4;
  }
}

export const perfBudget = new PerfBudget();
