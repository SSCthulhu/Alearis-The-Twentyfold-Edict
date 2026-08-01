import {
  HUD_BASE_HEIGHT,
  HUD_BASE_WIDTH,
  UI_COLORS,
  UI_FONTS,
  clamp01,
  drawDiamond,
  drawPanel,
  fillBar,
  formatClock,
  scaleForViewport,
  setCanvasDeviceSize,
} from './UiTheme';

export interface CooldownState {
  id: string;
  label: string;
  remaining: number;
  duration: number;
}

export interface DodgeChargeState {
  ready: boolean;
  remaining?: number;
  duration?: number;
}

export interface BossHudState {
  visible: boolean;
  name: string;
  hp: number;
  maxHp: number;
  castName?: string;
  castProgress?: number;
  castRemaining?: number;
}

export interface FloorHudState {
  world: number;
  floor: number;
  status: string;
  enemiesRemaining: number;
  fastClearRemaining: number;
}

export interface DiceHudState {
  min: number;
  max: number;
  lastRoll: number;
  meterCharge: number;
  activeEffect?: string;
  eventBanner?: string;
}

export interface MinimapFloorState {
  label: string;
  status: 'cleared' | 'current' | 'locked' | 'boss';
}

export interface HudState {
  hp: number;
  maxHp: number;
  shield: number;
  maxShield: number;
  ultimateRemaining: number;
  ultimateDuration: number;
  abilities: readonly CooldownState[];
  dodgeCharges: readonly DodgeChargeState[];
  boss: BossHudState;
  floor: FloorHudState;
  dice: DiceHudState;
  minimap: readonly MinimapFloorState[];
}

export interface HudRendererOptions {
  canvas?: HTMLCanvasElement;
  getState?: () => HudState;
}

const DEFAULT_STATE: HudState = {
  hp: 100,
  maxHp: 100,
  shield: 42,
  maxShield: 60,
  ultimateRemaining: 18,
  ultimateDuration: 45,
  abilities: [
    { id: 'primary', label: 'I', remaining: 0, duration: 6 },
    { id: 'special', label: 'II', remaining: 3.4, duration: 8 },
    { id: 'rune', label: 'III', remaining: 10, duration: 16 },
  ],
  dodgeCharges: [{ ready: true }, { ready: false, remaining: 1.2, duration: 4 }],
  boss: {
    visible: true,
    name: 'The Argent Witness',
    hp: 820,
    maxHp: 1200,
    castName: 'Edict of Ruin',
    castProgress: 0.42,
    castRemaining: 2.1,
  },
  floor: {
    world: 1,
    floor: 3,
    status: 'FROST COURT',
    enemiesRemaining: 7,
    fastClearRemaining: 21,
  },
  dice: {
    min: 8,
    max: 14,
    lastRoll: 12,
    meterCharge: 68,
    activeEffect: 'Council: Low Gravity Psalm',
    eventBanner: 'THE COUNCIL INTERVENES',
  },
  minimap: [
    { label: 'I', status: 'cleared' },
    { label: 'II', status: 'cleared' },
    { label: 'III', status: 'current' },
    { label: 'IV', status: 'locked' },
    { label: 'V', status: 'boss' },
  ],
};

export class HudRenderer {
  readonly canvas: HTMLCanvasElement;

  private readonly ctx: CanvasRenderingContext2D;
  private readonly getState: () => HudState;
  private animationFrame: number | null = null;
  private state: HudState = DEFAULT_STATE;
  private visible = true;

  constructor(options: HudRendererOptions = {}) {
    const canvas = options.canvas ?? document.querySelector<HTMLCanvasElement>('#hud-canvas');
    if (canvas === null) {
      throw new Error('HudRenderer requires a canvas or an element with id "hud-canvas".');
    }

    const context = canvas.getContext('2d');
    if (context === null) {
      throw new Error('HudRenderer could not acquire a 2D context.');
    }

    this.canvas = canvas;
    this.ctx = context;
    this.getState = options.getState ?? (() => this.state);
    this.resize();
  }

  setState(state: HudState): void {
    this.state = state;
  }

  setVisible(visible: boolean): void {
    if (this.visible === visible) return;
    this.visible = visible;
    this.canvas.style.visibility = visible ? 'visible' : 'hidden';
    if (!visible) {
      const width = this.canvas.clientWidth;
      const height = this.canvas.clientHeight;
      this.ctx.clearRect(0, 0, width, height);
    }
  }

  resize(): void {
    const parent = this.canvas.parentElement;
    const width = parent?.clientWidth ?? window.innerWidth;
    const height = parent?.clientHeight ?? window.innerHeight;
    const ratio = setCanvasDeviceSize(this.canvas, width, height);
    this.ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  }

  render(timestamp = performance.now()): void {
    this.resize();
    const width = this.canvas.clientWidth;
    const height = this.canvas.clientHeight;
    if (!this.visible) {
      this.ctx.clearRect(0, 0, width, height);
      return;
    }

    const state = this.getState();
    const scale = scaleForViewport(width, height);
    const offsetX = (width - HUD_BASE_WIDTH * scale) * 0.5;
    const offsetY = (height - HUD_BASE_HEIGHT * scale) * 0.5;

    this.ctx.clearRect(0, 0, width, height);
    this.ctx.save();
    this.ctx.translate(offsetX, offsetY);
    this.ctx.scale(scale, scale);
    this.drawVignette(timestamp);
    this.drawPlayerCluster(state);
    this.drawBossCluster(state.boss);
    this.drawFloorStatus(state.floor);
    this.drawDiceCluster(state.dice, timestamp);
    this.drawMinimap(state.minimap);
    this.ctx.restore();
  }

  start(): void {
    if (this.animationFrame !== null) return;
    const tick = (time: number): void => {
      this.render(time);
      this.animationFrame = requestAnimationFrame(tick);
    };
    this.animationFrame = requestAnimationFrame(tick);
  }

  stop(): void {
    if (this.animationFrame === null) return;
    cancelAnimationFrame(this.animationFrame);
    this.animationFrame = null;
  }

  private drawVignette(timestamp: number): void {
    const pulse = 0.5 + Math.sin(timestamp * 0.0015) * 0.5;
    const ctx = this.ctx;
    ctx.save();
    const gradient = ctx.createRadialGradient(1280, 720, 220, 1280, 720, 1140);
    gradient.addColorStop(0, 'rgba(0, 0, 0, 0)');
    gradient.addColorStop(0.78, 'rgba(0, 0, 0, 0.08)');
    gradient.addColorStop(1, `rgba(0, 0, 0, ${0.34 + pulse * 0.05})`);
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, HUD_BASE_WIDTH, HUD_BASE_HEIGHT);
    ctx.restore();
  }

  private drawPlayerCluster(state: HudState): void {
    const ctx = this.ctx;
    drawPanel(ctx, { x: 54, y: 54, w: 760, h: 214 }, { title: 'VITALS', glow: true });

    ctx.save();
    ctx.font = `900 34px ${UI_FONTS.title}`;
    ctx.fillStyle = UI_COLORS.ivory;
    ctx.fillText('ALEATORE', 86, 120);
    ctx.font = `700 20px ${UI_FONTS.mono}`;
    ctx.fillStyle = UI_COLORS.goldBright;
    ctx.fillText('ASCENDANT VESSEL', 88, 150);
    ctx.restore();

    fillBar(ctx, { x: 300, y: 92, w: 456, h: 34 }, safeRatio(state.hp, state.maxHp), UI_COLORS.red, 'rgba(75, 23, 24, 0.65)');
    fillBar(ctx, { x: 300, y: 142, w: 456, h: 26 }, safeRatio(state.shield, state.maxShield), UI_COLORS.blue, 'rgba(23, 38, 55, 0.68)');
    this.drawValueText(`${Math.ceil(state.hp)} / ${Math.ceil(state.maxHp)}`, 528, 119);
    this.drawValueText(`${Math.ceil(state.shield)} / ${Math.ceil(state.maxShield)}`, 528, 164);

    this.drawUltimate(state.ultimateRemaining, state.ultimateDuration);
    this.drawAbilityCooldowns(state.abilities);
    this.drawDodgeCharges(state.dodgeCharges);
  }

  private drawUltimate(remaining: number, duration: number): void {
    const ctx = this.ctx;
    const centerX = 128;
    const centerY = 338;
    const radius = 62;
    const ready = remaining <= 0;
    const ratio = 1 - safeRatio(remaining, duration);

    drawPanel(ctx, { x: 54, y: 288, w: 196, h: 156 }, { alpha: 0.76, chamfer: 22 });
    ctx.save();
    ctx.translate(centerX, centerY);
    this.drawRuneGlyph(0, 0, radius * 0.72, ready ? UI_COLORS.goldBright : UI_COLORS.goldDim);
    ctx.beginPath();
    ctx.arc(0, 0, radius, -Math.PI * 0.5, -Math.PI * 0.5 + Math.PI * 2 * ratio);
    ctx.strokeStyle = ready ? UI_COLORS.goldBright : UI_COLORS.gold;
    ctx.lineWidth = 8;
    ctx.stroke();
    ctx.font = `800 17px ${UI_FONTS.mono}`;
    ctx.textAlign = 'center';
    ctx.fillStyle = UI_COLORS.ivory;
    ctx.fillText(ready ? 'ULT' : `${remaining.toFixed(0)}s`, 0, 82);
    ctx.restore();
  }

  private drawAbilityCooldowns(abilities: readonly CooldownState[]): void {
    const ctx = this.ctx;
    drawPanel(ctx, { x: 270, y: 290, w: 352, h: 154 }, { alpha: 0.72, chamfer: 22, title: 'ARTS' });

    abilities.slice(0, 4).forEach((ability, index) => {
      const x = 304 + index * 78;
      const y = 350;
      const ready = ability.remaining <= 0;
      drawDiamond(ctx, x, y, 31, ready ? 'rgba(214, 174, 84, 0.3)' : 'rgba(255, 255, 255, 0.07)');
      if (!ready) {
        ctx.save();
        ctx.beginPath();
        ctx.rect(x - 31, y - 31, 62, 62 * safeRatio(ability.remaining, ability.duration));
        ctx.fillStyle = 'rgba(0, 0, 0, 0.48)';
        ctx.fill();
        ctx.restore();
      }
      ctx.save();
      ctx.font = `900 20px ${UI_FONTS.mono}`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = ready ? UI_COLORS.goldBright : UI_COLORS.muted;
      ctx.fillText(ability.label, x, y);
      ctx.font = `700 12px ${UI_FONTS.mono}`;
      ctx.fillText(ready ? 'READY' : `${ability.remaining.toFixed(1)}s`, x, y + 50);
      ctx.restore();
    });
  }

  private drawDodgeCharges(charges: readonly DodgeChargeState[]): void {
    const ctx = this.ctx;
    drawPanel(ctx, { x: 640, y: 290, w: 174, h: 154 }, { alpha: 0.72, chamfer: 22, title: 'DODGE' });

    const count = Math.max(2, Math.min(3, charges.length));
    for (let i = 0; i < count; i++) {
      const charge = charges[i] ?? { ready: false, remaining: 0, duration: 1 };
      const x = count > 2 ? 672 + i * 48 : 686 + i * 74;
      const y = 360;
      const ready = charge.ready;
      ctx.save();
      ctx.strokeStyle = ready ? UI_COLORS.goldBright : UI_COLORS.goldDim;
      ctx.fillStyle = ready ? 'rgba(255, 224, 154, 0.22)' : 'rgba(255, 255, 255, 0.06)';
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.ellipse(x, y, 24, 38, 0.16, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      if (!ready) {
        const remaining = charge.remaining ?? 0;
        const duration = charge.duration ?? 1;
        ctx.fillStyle = 'rgba(0, 0, 0, 0.52)';
        ctx.fillRect(x - 28, y - 42, 56, 84 * safeRatio(remaining, duration));
      }
      ctx.restore();
    }
  }

  private drawBossCluster(boss: BossHudState): void {
    if (!boss.visible) return;

    const ctx = this.ctx;
    drawPanel(ctx, { x: 760, y: 44, w: 1040, h: 146 }, { alpha: 0.78, accent: UI_COLORS.red, chamfer: 26 });
    ctx.save();
    ctx.font = `900 38px ${UI_FONTS.title}`;
    ctx.textAlign = 'center';
    ctx.fillStyle = UI_COLORS.ivory;
    ctx.fillText(boss.name.toUpperCase(), 1280, 92);
    ctx.restore();

    fillBar(ctx, { x: 860, y: 116, w: 840, h: 34 }, safeRatio(boss.hp, boss.maxHp), UI_COLORS.red, 'rgba(75, 23, 24, 0.72)');
    this.drawValueText(`${Math.ceil(boss.hp)} / ${Math.ceil(boss.maxHp)}`, 1280, 141);

    if (boss.castName !== undefined && boss.castName.length > 0) {
      const castProgress = boss.castProgress ?? 0;
      drawPanel(ctx, { x: 942, y: 198, w: 676, h: 76 }, { alpha: 0.66, accent: UI_COLORS.void, chamfer: 18 });
      fillBar(ctx, { x: 984, y: 230, w: 430, h: 18 }, castProgress, UI_COLORS.void, 'rgba(80, 57, 130, 0.34)');
      ctx.save();
      ctx.font = `800 18px ${UI_FONTS.mono}`;
      ctx.fillStyle = UI_COLORS.goldBright;
      ctx.fillText(boss.castName.toUpperCase(), 986, 222);
      ctx.textAlign = 'right';
      ctx.fillStyle = UI_COLORS.ivory;
      ctx.fillText(`${(boss.castRemaining ?? 0).toFixed(1)}s`, 1578, 244);
      ctx.restore();
    }
  }

  private drawFloorStatus(floor: FloorHudState): void {
    const ctx = this.ctx;
    drawPanel(ctx, { x: 1802, y: 54, w: 704, h: 214 }, { alpha: 0.78, chamfer: 26, title: 'FLOOR STATUS' });
    ctx.save();
    ctx.font = `900 36px ${UI_FONTS.title}`;
    ctx.fillStyle = UI_COLORS.ivory;
    ctx.fillText(`WORLD ${floor.world} / FLOOR ${floor.floor}`, 1840, 128);
    ctx.font = `800 20px ${UI_FONTS.mono}`;
    ctx.fillStyle = UI_COLORS.goldBright;
    ctx.fillText(floor.status.toUpperCase(), 1842, 160);
    ctx.font = `700 22px ${UI_FONTS.body}`;
    ctx.fillStyle = UI_COLORS.muted;
    ctx.fillText(`Enemies remaining: ${floor.enemiesRemaining}`, 1842, 204);
    ctx.fillStyle = floor.fastClearRemaining <= 8 ? UI_COLORS.red : UI_COLORS.gold;
    ctx.fillText(`Fast-clear tithe: ${formatClock(floor.fastClearRemaining)}`, 1842, 238);
    ctx.restore();
  }

  private drawDiceCluster(dice: DiceHudState, timestamp: number): void {
    const ctx = this.ctx;
    drawPanel(ctx, { x: 1744, y: 1010, w: 762, h: 358 }, { alpha: 0.82, glow: true, title: 'DICE ORACLE' });
    ctx.save();
    ctx.font = `900 74px ${UI_FONTS.title}`;
    ctx.fillStyle = UI_COLORS.goldBright;
    ctx.fillText(`${dice.min} - ${dice.max}`, 1790, 1124);
    ctx.font = `800 22px ${UI_FONTS.mono}`;
    ctx.fillStyle = UI_COLORS.muted;
    ctx.fillText(`LAST ROLL: ${dice.lastRoll}`, 1800, 1164);
    ctx.restore();

    this.drawDiceMeter(dice.meterCharge, 1796, 1210, 638, 38);

    if (dice.activeEffect !== undefined && dice.activeEffect.length > 0) {
      ctx.save();
      ctx.font = `700 23px ${UI_FONTS.body}`;
      ctx.fillStyle = UI_COLORS.ivory;
      ctx.fillText(dice.activeEffect, 1798, 1296);
      ctx.restore();
    }

    if (dice.eventBanner !== undefined && dice.eventBanner.length > 0) {
      this.drawEventBanner(dice.eventBanner, timestamp);
    }
  }

  private drawDiceMeter(charge: number, x: number, y: number, w: number, h: number): void {
    const ctx = this.ctx;
    const ratio = clamp01(charge / 100);
    fillBar(ctx, { x, y, w, h }, ratio, UI_COLORS.gold, 'rgba(214, 174, 84, 0.12)');
    ctx.save();
    ctx.font = `800 18px ${UI_FONTS.mono}`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = UI_COLORS.black;
    ctx.fillText(`${Math.round(ratio * 100)}% COUNCIL CHARGE`, x + w * 0.5, y + h * 0.52);
    ctx.restore();
  }

  private drawEventBanner(text: string, timestamp: number): void {
    const ctx = this.ctx;
    const pulse = 0.72 + Math.sin(timestamp * 0.009) * 0.18;
    drawPanel(ctx, { x: 744, y: 1160, w: 1072, h: 120 }, { alpha: 0.72, accent: UI_COLORS.divine, chamfer: 30, glow: true });
    ctx.save();
    ctx.globalAlpha = pulse;
    ctx.font = `900 42px ${UI_FONTS.title}`;
    ctx.textAlign = 'center';
    ctx.fillStyle = UI_COLORS.divine;
    ctx.fillText(text.toUpperCase(), 1280, 1238);
    ctx.restore();
  }

  private drawMinimap(floors: readonly MinimapFloorState[]): void {
    const ctx = this.ctx;
    drawPanel(ctx, { x: 82, y: 994, w: 260, h: 374 }, { alpha: 0.74, chamfer: 26, title: 'ASCENT' });
    floors.slice(0, 5).forEach((floor, index) => {
      const y = 1300 - index * 54;
      const current = floor.status === 'current';
      const boss = floor.status === 'boss';
      const fill = floor.status === 'cleared'
        ? 'rgba(214, 174, 84, 0.38)'
        : current
          ? 'rgba(255, 224, 154, 0.5)'
          : boss
            ? 'rgba(214, 90, 84, 0.28)'
            : 'rgba(255, 255, 255, 0.06)';
      drawDiamond(ctx, 144, y, current ? 24 : 19, fill, boss ? UI_COLORS.red : UI_COLORS.gold);
      ctx.save();
      ctx.font = `800 18px ${UI_FONTS.mono}`;
      ctx.textBaseline = 'middle';
      ctx.fillStyle = current ? UI_COLORS.goldBright : UI_COLORS.muted;
      ctx.fillText(floor.label, 188, y + 1);
      ctx.restore();
    });
  }

  private drawRuneGlyph(x: number, y: number, radius: number, color: string): void {
    const ctx = this.ctx;
    ctx.save();
    ctx.strokeStyle = color;
    ctx.fillStyle = 'rgba(214, 174, 84, 0.12)';
    ctx.lineWidth = 4;
    ctx.beginPath();
    for (let i = 0; i < 6; i++) {
      const angle = -Math.PI * 0.5 + i * (Math.PI / 3);
      const px = x + Math.cos(angle) * radius;
      const py = y + Math.sin(angle) * radius;
      if (i === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(x - radius * 0.52, y);
    ctx.lineTo(x, y - radius * 0.58);
    ctx.lineTo(x + radius * 0.52, y);
    ctx.lineTo(x, y + radius * 0.58);
    ctx.closePath();
    ctx.stroke();
    ctx.restore();
  }

  private drawValueText(text: string, x: number, y: number): void {
    const ctx = this.ctx;
    ctx.save();
    ctx.font = `800 18px ${UI_FONTS.mono}`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = UI_COLORS.ivory;
    ctx.fillText(text, x, y);
    ctx.restore();
  }
}

function safeRatio(value: number, max: number): number {
  if (max <= 0) return 0;
  return clamp01(value / max);
}
