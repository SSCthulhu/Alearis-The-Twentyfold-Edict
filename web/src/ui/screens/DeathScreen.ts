import { UI_COLORS, createButton, createPanel, createScreenRoot, formatClock, installUiTheme, mountElement } from '../UiTheme';

export interface DeathScreenStats {
  world: number;
  floor: number;
  runTimeSeconds: number;
  kills: number;
  lastRoll: number;
}

export interface DeathScreenOptions {
  root?: HTMLElement | string;
  stats?: DeathScreenStats;
  cause?: string;
  title?: string;
  kicker?: string;
  variant?: 'death' | 'victory';
  onRetry?: () => void;
  onMainMenu?: () => void;
}

const DEFAULT_STATS: DeathScreenStats = {
  world: 2,
  floor: 4,
  runTimeSeconds: 642,
  kills: 73,
  lastRoll: 16,
};

export class DeathScreen {
  readonly element: HTMLDivElement;

  private readonly options: DeathScreenOptions;
  private stats: DeathScreenStats;

  constructor(options: DeathScreenOptions = {}) {
    installUiTheme();
    this.options = options;
    this.stats = options.stats ?? DEFAULT_STATS;
    this.element = createScreenRoot('alearis-death-screen');
    if (options.variant === 'victory') this.element.classList.add('alearis-death-screen--victory');
    this.element.appendChild(this.buildPanel());
    this.installScreenStyle();

    if (options.root !== undefined) {
      this.mount(options.root);
    }
  }

  mount(root?: HTMLElement | string): void {
    if (this.element.parentElement === null) {
      mountElement(root, this.element);
    }
  }

  unmount(): void {
    this.element.remove();
  }

  setStats(stats: DeathScreenStats): void {
    this.stats = stats;
    this.element.replaceChildren(this.buildPanel());
  }

  private buildPanel(): HTMLDivElement {
    const panel = createPanel('alearis-death-screen__panel');
    const glyph = document.createElement('canvas');
    glyph.width = 280;
    glyph.height = 220;
    glyph.className = 'alearis-death-screen__glyph';
    drawDeathGlyph(glyph, this.options.variant ?? 'death');

    const content = document.createElement('div');
    content.innerHTML = `
      <div class="alearis-kicker">${this.options.kicker ?? 'Run Ended'}</div>
      <h2 class="alearis-title">${this.options.title ?? 'The Edict Holds'}</h2>
      <p class="alearis-copy">${this.options.cause ?? 'Your vessel fell before the ascent could be completed.'}</p>
      <dl class="alearis-death-screen__stats">
        <div><dt>Depth</dt><dd>World ${this.stats.world} / Floor ${this.stats.floor}</dd></div>
        <div><dt>Run Time</dt><dd>${formatClock(this.stats.runTimeSeconds)}</dd></div>
        <div><dt>Kills</dt><dd>${this.stats.kills}</dd></div>
        <div><dt>Last Roll</dt><dd>${this.stats.lastRoll}</dd></div>
      </dl>
    `;

    const actions = document.createElement('div');
    actions.className = 'alearis-death-screen__actions';
    actions.append(
      createButton({ label: this.options.variant === 'victory' ? 'New Run' : 'Retry Run', variant: this.options.variant === 'victory' ? 'primary' : 'danger', onClick: this.options.onRetry }),
      createButton({ label: 'Main Menu', variant: 'secondary', onClick: this.options.onMainMenu }),
    );

    panel.append(glyph, content, actions);
    return panel;
  }

  private installScreenStyle(): void {
    const id = 'alearis-death-screen-style';
    if (document.getElementById(id) !== null) return;

    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      .alearis-death-screen {
        background:
          radial-gradient(circle at 50% 20%, rgba(214, 90, 84, 0.16), transparent 36%),
          linear-gradient(120deg, rgba(4, 5, 9, 0.86), rgba(0, 0, 0, 0.94));
      }

      .alearis-death-screen__panel {
        width: min(1120px, 92vw);
        padding: clamp(34px, 4vw, 72px);
        display: grid;
        grid-template-columns: 300px minmax(320px, 1fr);
        gap: clamp(28px, 4vw, 64px);
        align-items: center;
        border-color: rgba(214, 90, 84, 0.65);
      }

      .alearis-death-screen .alearis-title {
        color: ${UI_COLORS.red};
        font-size: clamp(50px, 5vw, 100px);
      }

      .alearis-death-screen--victory {
        background:
          radial-gradient(circle at 50% 20%, rgba(214, 174, 84, 0.2), transparent 38%),
          linear-gradient(120deg, rgba(6, 5, 2, 0.84), rgba(0, 0, 0, 0.92));
      }

      .alearis-death-screen--victory .alearis-death-screen__panel {
        border-color: rgba(214, 174, 84, 0.72);
      }

      .alearis-death-screen--victory .alearis-title {
        color: ${UI_COLORS.goldBright};
      }

      .alearis-death-screen__glyph {
        width: 280px;
        max-width: 100%;
        height: auto;
      }

      .alearis-death-screen__stats {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 12px;
        margin: 28px 0 0;
      }

      .alearis-death-screen__stats div {
        padding: 14px 16px;
        border: 1px solid rgba(255, 255, 255, 0.12);
        background: rgba(255, 255, 255, 0.04);
      }

      .alearis-death-screen__stats dt {
        color: ${UI_COLORS.muted};
        font: 800 12px "Cascadia Mono", monospace;
        letter-spacing: 0.14em;
        text-transform: uppercase;
      }

      .alearis-death-screen__stats dd {
        margin: 6px 0 0;
        color: ${UI_COLORS.ivory};
        font: 900 22px "Segoe UI", sans-serif;
      }

      .alearis-death-screen__actions {
        grid-column: 1 / -1;
        display: flex;
        justify-content: flex-end;
        gap: 14px;
      }
    `;
    document.head.appendChild(style);
  }
}

function drawDeathGlyph(canvas: HTMLCanvasElement, variant: 'death' | 'victory'): void {
  const ctx = canvas.getContext('2d');
  if (ctx === null) return;
  const primary = variant === 'victory' ? UI_COLORS.goldBright : UI_COLORS.red;
  const fill = variant === 'victory' ? 'rgba(214, 174, 84, 0.13)' : 'rgba(214, 90, 84, 0.1)';

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.save();
  ctx.translate(140, 110);
  ctx.strokeStyle = primary;
  ctx.fillStyle = fill;
  ctx.lineWidth = 7;
  ctx.beginPath();
  ctx.arc(0, -12, 54, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  if (variant === 'victory') {
    ctx.beginPath();
    ctx.moveTo(0, -92);
    ctx.lineTo(78, -22);
    ctx.lineTo(48, 80);
    ctx.lineTo(-48, 80);
    ctx.lineTo(-78, -22);
    ctx.closePath();
    ctx.stroke();
  } else {
    ctx.beginPath();
    ctx.moveTo(-82, 74);
    ctx.lineTo(82, -74);
    ctx.moveTo(-82, -74);
    ctx.lineTo(82, 74);
    ctx.stroke();
  }
  ctx.fillStyle = UI_COLORS.ivory;
  ctx.beginPath();
  ctx.arc(-18, -20, 7, 0, Math.PI * 2);
  ctx.arc(18, -20, 7, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}
