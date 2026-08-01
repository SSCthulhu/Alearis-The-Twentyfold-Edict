export const HUD_BASE_WIDTH = 2560;
export const HUD_BASE_HEIGHT = 1440;

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface PanelDrawOptions {
  alpha?: number;
  accent?: string;
  borderWidth?: number;
  chamfer?: number;
  glow?: boolean;
  title?: string;
}

export interface UiButtonOptions {
  label: string;
  variant?: 'primary' | 'secondary' | 'danger';
  onClick?: () => void;
}

export const UI_COLORS = {
  black: '#05060a',
  ink: '#090b12',
  panel: 'rgba(10, 12, 20, 0.82)',
  panelStrong: 'rgba(8, 9, 14, 0.94)',
  panelSoft: 'rgba(18, 21, 34, 0.64)',
  gold: '#d6ae54',
  goldBright: '#ffe09a',
  goldDim: '#7e622e',
  ivory: '#f4ead2',
  muted: '#a99f8f',
  red: '#d65a54',
  redDark: '#4b1718',
  blue: '#7fb6d9',
  frost: '#acd7ff',
  void: '#9b7cff',
  forge: '#ff9d4d',
  divine: '#fff3bd',
  poison: '#78c46b',
  shadow: 'rgba(0, 0, 0, 0.55)',
} as const;

export const UI_FONTS = {
  title: '"Cinzel", "Palatino Linotype", Georgia, serif',
  body: '"Segoe UI", "Inter", system-ui, sans-serif',
  mono: '"Cascadia Mono", "Consolas", monospace',
} as const;

export function scaleForViewport(width: number, height: number): number {
  return Math.min(width / HUD_BASE_WIDTH, height / HUD_BASE_HEIGHT);
}

export function setCanvasDeviceSize(canvas: HTMLCanvasElement, logicalWidth: number, logicalHeight: number): number {
  const ratio = Math.max(1, Math.min(window.devicePixelRatio || 1, 3));
  const targetWidth = Math.max(1, Math.floor(logicalWidth * ratio));
  const targetHeight = Math.max(1, Math.floor(logicalHeight * ratio));

  if (canvas.width !== targetWidth) canvas.width = targetWidth;
  if (canvas.height !== targetHeight) canvas.height = targetHeight;

  canvas.style.width = `${logicalWidth}px`;
  canvas.style.height = `${logicalHeight}px`;
  return ratio;
}

export function traceChamferedRect(ctx: CanvasRenderingContext2D, rect: Rect, chamfer: number): void {
  const cut = Math.max(0, Math.min(chamfer, rect.w * 0.24, rect.h * 0.24));
  ctx.beginPath();
  ctx.moveTo(rect.x + cut, rect.y);
  ctx.lineTo(rect.x + rect.w - cut, rect.y);
  ctx.lineTo(rect.x + rect.w, rect.y + cut);
  ctx.lineTo(rect.x + rect.w, rect.y + rect.h - cut);
  ctx.lineTo(rect.x + rect.w - cut, rect.y + rect.h);
  ctx.lineTo(rect.x + cut, rect.y + rect.h);
  ctx.lineTo(rect.x, rect.y + rect.h - cut);
  ctx.lineTo(rect.x, rect.y + cut);
  ctx.closePath();
}

export function drawPanel(ctx: CanvasRenderingContext2D, rect: Rect, options: PanelDrawOptions = {}): void {
  const accent = options.accent ?? UI_COLORS.gold;
  const alpha = options.alpha ?? 0.84;
  const chamfer = options.chamfer ?? Math.min(rect.w, rect.h) * 0.12;

  ctx.save();
  traceChamferedRect(ctx, rect, chamfer);
  ctx.fillStyle = `rgba(8, 10, 17, ${alpha})`;
  ctx.fill();

  const gradient = ctx.createLinearGradient(rect.x, rect.y, rect.x + rect.w, rect.y + rect.h);
  gradient.addColorStop(0, 'rgba(255, 224, 154, 0.16)');
  gradient.addColorStop(0.38, 'rgba(255, 224, 154, 0.02)');
  gradient.addColorStop(1, 'rgba(0, 0, 0, 0.28)');
  ctx.fillStyle = gradient;
  ctx.fill();

  if (options.glow === true) {
    ctx.shadowColor = accent;
    ctx.shadowBlur = 18;
  }

  ctx.lineWidth = options.borderWidth ?? 3;
  ctx.strokeStyle = accent;
  ctx.stroke();

  ctx.shadowBlur = 0;
  ctx.lineWidth = 1;
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.14)';
  traceChamferedRect(ctx, insetRect(rect, 7), Math.max(0, chamfer - 7));
  ctx.stroke();

  if (options.title !== undefined && options.title.length > 0) {
    drawPanelTitle(ctx, rect, options.title, accent);
  }

  ctx.restore();
}

export function drawPanelTitle(ctx: CanvasRenderingContext2D, rect: Rect, title: string, accent: string = UI_COLORS.gold): void {
  ctx.save();
  ctx.font = `700 30px ${UI_FONTS.title}`;
  ctx.textBaseline = 'middle';
  ctx.fillStyle = accent;
  ctx.fillText(title.toUpperCase(), rect.x + 28, rect.y + 30);
  ctx.strokeStyle = accent;
  ctx.globalAlpha = 0.55;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(rect.x + 28, rect.y + 58);
  ctx.lineTo(rect.x + rect.w - 28, rect.y + 58);
  ctx.stroke();
  ctx.restore();
}

export interface BarOptions {
  /** Trailing value the bar drains toward; renders as a lag ghost band. */
  ghost?: number;
  ghostColor?: string;
  /** Bright cap on the fill's leading edge. On by default. */
  leadingEdge?: boolean;
}

export function fillBar(
  ctx: CanvasRenderingContext2D,
  rect: Rect,
  ratio: number,
  fill: string,
  back = 'rgba(255, 255, 255, 0.08)',
  options: BarOptions = {},
): void {
  const clamped = clamp01(ratio);
  const ghost = clamp01(options.ghost ?? 0);
  const chamfer = Math.min(rect.h * 0.4, 14);

  ctx.save();
  traceChamferedRect(ctx, rect, chamfer);
  ctx.fillStyle = back;
  ctx.fill();
  ctx.clip();

  // Lag ghost sits between the new value and the old one, so a hit reads as a
  // measurable bite out of the bar rather than an instant jump.
  if (ghost > clamped) {
    ctx.fillStyle = options.ghostColor ?? 'rgba(255, 226, 168, 0.5)';
    ctx.fillRect(rect.x + rect.w * clamped, rect.y, rect.w * (ghost - clamped), rect.h);
  }

  ctx.fillStyle = fill;
  ctx.fillRect(rect.x, rect.y, rect.w * clamped, rect.h);

  if (options.leadingEdge !== false && clamped > 0.004 && clamped < 0.997) {
    const capWidth = Math.max(4, rect.h * 0.16);
    ctx.fillStyle = UI_COLORS.goldBright;
    ctx.fillRect(rect.x + rect.w * clamped - capWidth, rect.y, capWidth, rect.h);
  }
  ctx.restore();

  ctx.save();
  ctx.strokeStyle = UI_COLORS.goldDim;
  ctx.lineWidth = 2.5;
  traceChamferedRect(ctx, rect, chamfer);
  ctx.stroke();
  ctx.restore();
}

export function drawDiamond(ctx: CanvasRenderingContext2D, x: number, y: number, size: number, fill: string, stroke: string = UI_COLORS.gold): void {
  ctx.save();
  ctx.beginPath();
  ctx.moveTo(x, y - size);
  ctx.lineTo(x + size, y);
  ctx.lineTo(x, y + size);
  ctx.lineTo(x - size, y);
  ctx.closePath();
  ctx.fillStyle = fill;
  ctx.fill();
  ctx.strokeStyle = stroke;
  ctx.lineWidth = Math.max(1, size * 0.12);
  ctx.stroke();
  ctx.restore();
}

export function insetRect(rect: Rect, amount: number): Rect {
  return {
    x: rect.x + amount,
    y: rect.y + amount,
    w: Math.max(0, rect.w - amount * 2),
    h: Math.max(0, rect.h - amount * 2),
  };
}

export function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}

export function formatClock(seconds: number): string {
  const safe = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(safe / 60);
  const remaining = safe % 60;
  return `${minutes}:${remaining.toString().padStart(2, '0')}`;
}

export function installUiTheme(root: Document | ShadowRoot = document): HTMLStyleElement {
  const id = 'alearis-ui-theme';
  const existing = root.getElementById?.(id);
  if (existing instanceof HTMLStyleElement) return existing;

  const style = document.createElement('style');
  style.id = id;
  style.textContent = `
    :root {
      --alearis-black: ${UI_COLORS.black};
      --alearis-panel: ${UI_COLORS.panel};
      --alearis-gold: ${UI_COLORS.gold};
      --alearis-gold-bright: ${UI_COLORS.goldBright};
      --alearis-ivory: ${UI_COLORS.ivory};
      --alearis-muted: ${UI_COLORS.muted};
      --alearis-red: ${UI_COLORS.red};
      color: var(--alearis-ivory);
      background: var(--alearis-black);
      font-family: ${UI_FONTS.body};
    }

    .alearis-screen {
      position: absolute;
      inset: 0;
      display: grid;
      place-items: center;
      padding: clamp(24px, 4vw, 96px);
      box-sizing: border-box;
      color: var(--alearis-ivory);
      pointer-events: auto;
      background:
        radial-gradient(circle at 50% 18%, rgba(214, 174, 84, 0.13), transparent 38%),
        linear-gradient(120deg, rgba(4, 6, 12, 0.62), rgba(4, 5, 9, 0.9));
    }

    .alearis-panel {
      position: relative;
      box-sizing: border-box;
      border: 1px solid rgba(255, 224, 154, 0.55);
      color: var(--alearis-ivory);
      background:
        linear-gradient(135deg, rgba(255, 224, 154, 0.12), transparent 34%),
        linear-gradient(180deg, rgba(11, 13, 22, 0.96), rgba(5, 6, 10, 0.92));
      box-shadow: 0 26px 72px rgba(0, 0, 0, 0.58), inset 0 0 0 1px rgba(255, 255, 255, 0.08);
      clip-path: polygon(28px 0, calc(100% - 28px) 0, 100% 28px, 100% calc(100% - 28px), calc(100% - 28px) 100%, 28px 100%, 0 calc(100% - 28px), 0 28px);
    }

    .alearis-kicker {
      color: var(--alearis-gold-bright);
      font: 700 clamp(12px, 0.95vw, 18px) ${UI_FONTS.mono};
      letter-spacing: 0.22em;
      text-transform: uppercase;
    }

    .alearis-title {
      margin: 0;
      color: var(--alearis-ivory);
      font-family: ${UI_FONTS.title};
      font-weight: 800;
      line-height: 0.92;
      text-transform: uppercase;
      text-shadow: 0 0 34px rgba(214, 174, 84, 0.26);
    }

    .alearis-copy {
      color: var(--alearis-muted);
      font-size: clamp(15px, 1vw, 22px);
      line-height: 1.55;
    }

    .alearis-button {
      appearance: none;
      border: 1px solid rgba(255, 224, 154, 0.68);
      min-height: 48px;
      padding: 14px 24px;
      color: var(--alearis-ivory);
      background:
        linear-gradient(90deg, rgba(214, 174, 84, 0.3), rgba(214, 174, 84, 0.08)),
        rgba(9, 11, 18, 0.96);
      clip-path: polygon(14px 0, 100% 0, calc(100% - 14px) 100%, 0 100%);
      cursor: pointer;
      font: 800 clamp(13px, 0.78vw, 16px) ${UI_FONTS.mono};
      letter-spacing: 0.12em;
      text-transform: uppercase;
      transition: transform 120ms ease, border-color 120ms ease, background 120ms ease;
    }

    .alearis-button:hover,
    .alearis-button:focus-visible {
      border-color: var(--alearis-gold-bright);
      background:
        linear-gradient(90deg, rgba(255, 224, 154, 0.38), rgba(214, 174, 84, 0.14)),
        rgba(10, 12, 20, 0.98);
      transform: translateY(-1px);
      outline: none;
    }

    .alearis-button.secondary {
      border-color: rgba(255, 255, 255, 0.18);
      background: rgba(10, 12, 20, 0.84);
      color: var(--alearis-muted);
    }

    .alearis-button.danger {
      border-color: rgba(214, 90, 84, 0.78);
      background: linear-gradient(90deg, rgba(214, 90, 84, 0.28), rgba(214, 90, 84, 0.08)), rgba(10, 12, 20, 0.96);
    }

    .alearis-card-grid {
      display: grid;
      grid-template-columns: repeat(var(--alearis-card-count, 3), minmax(0, 1fr));
      gap: clamp(14px, 1.2vw, 28px);
    }

    .alearis-card {
      position: relative;
      min-height: 280px;
      padding: clamp(18px, 1.4vw, 30px);
      overflow: hidden;
    }

    .alearis-card::before {
      content: "";
      position: absolute;
      inset: 0;
      background: radial-gradient(circle at 24% 16%, rgba(255, 224, 154, 0.16), transparent 30%);
      pointer-events: none;
    }

    .alearis-card h3 {
      position: relative;
      margin: 12px 0;
      font: 800 clamp(22px, 1.5vw, 34px) ${UI_FONTS.title};
      text-transform: uppercase;
    }

    .alearis-card p {
      position: relative;
      color: var(--alearis-muted);
      font-size: clamp(14px, 0.92vw, 19px);
      line-height: 1.45;
    }

    .alearis-range {
      width: min(460px, 100%);
      accent-color: var(--alearis-gold);
    }
  `;
  (root instanceof Document ? root.head : root).appendChild(style);
  return style;
}

export function createScreenRoot(className = ''): HTMLDivElement {
  installUiTheme();
  const element = document.createElement('div');
  element.className = `alearis-screen ${className}`.trim();
  return element;
}

export function createPanel(className = ''): HTMLDivElement {
  installUiTheme();
  const element = document.createElement('div');
  element.className = `alearis-panel ${className}`.trim();
  return element;
}

export function createButton(options: UiButtonOptions): HTMLButtonElement {
  installUiTheme();
  const button = document.createElement('button');
  button.type = 'button';
  button.className = `alearis-button ${options.variant ?? 'primary'}`.trim();
  button.textContent = options.label;
  if (options.onClick !== undefined) {
    button.addEventListener('click', options.onClick);
  }
  return button;
}

export function mountElement(root: HTMLElement | string | undefined, element: HTMLElement): HTMLElement {
  const target = typeof root === 'string' ? document.querySelector<HTMLElement>(root) : root;
  const resolved = target ?? document.querySelector<HTMLElement>('#ui-root') ?? document.body;
  resolved.appendChild(element);
  return resolved;
}
