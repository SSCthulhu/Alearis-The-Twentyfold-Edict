import { UI_COLORS, createPanel, installUiTheme, mountElement } from '../UiTheme';

export interface DiceEventBannerPayload {
  title: string;
  subtitle?: string;
  activeEffect?: string;
  tone?: 'council' | 'divine' | 'danger';
  durationMs?: number;
}

export interface DiceEventBannerOptions {
  root?: HTMLElement | string;
  onDone?: () => void;
}

export class DiceEventBanner {
  readonly element: HTMLDivElement;

  private readonly options: DiceEventBannerOptions;
  private hideTimer: number | null = null;
  private sigil: HTMLCanvasElement;

  constructor(options: DiceEventBannerOptions = {}) {
    installUiTheme();
    this.options = options;
    this.element = createPanel('alearis-dice-event-banner');
    this.element.hidden = true;
    this.sigil = document.createElement('canvas');
    this.sigil.width = 132;
    this.sigil.height = 132;
    this.sigil.className = 'alearis-dice-event-banner__sigil';
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
    if (this.hideTimer !== null) window.clearTimeout(this.hideTimer);
    this.element.remove();
  }

  show(payload: DiceEventBannerPayload): void {
    if (this.hideTimer !== null) window.clearTimeout(this.hideTimer);

    const tone = payload.tone ?? 'council';
    this.element.className = `alearis-panel alearis-dice-event-banner tone-${tone}`;
    this.element.replaceChildren();
    drawBannerSigil(this.sigil, tone);

    const copy = document.createElement('div');
    copy.className = 'alearis-dice-event-banner__copy';
    copy.innerHTML = `
      <div class="alearis-kicker">${payload.subtitle ?? 'Dice Event'}</div>
      <div class="alearis-dice-event-banner__title">${payload.title}</div>
      <div class="alearis-dice-event-banner__effect">${payload.activeEffect ?? 'Awaiting active effect'}</div>
    `;

    this.element.append(this.sigil, copy);
    this.element.hidden = false;
    this.element.classList.remove('leaving');

    this.hideTimer = window.setTimeout(() => this.hide(), payload.durationMs ?? 3600);
  }

  hide(): void {
    this.element.classList.add('leaving');
    this.hideTimer = window.setTimeout(() => {
      this.element.hidden = true;
      this.options.onDone?.();
    }, 260);
  }

  private installScreenStyle(): void {
    const id = 'alearis-dice-event-banner-style';
    if (document.getElementById(id) !== null) return;

    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      .alearis-dice-event-banner {
        position: absolute;
        left: 50%;
        top: clamp(80px, 9vh, 160px);
        z-index: 8;
        display: grid;
        grid-template-columns: 132px minmax(340px, 720px);
        gap: 22px;
        align-items: center;
        width: min(940px, calc(100vw - 48px));
        padding: 22px 30px;
        transform: translateX(-50%);
        animation: alearis-banner-in 260ms ease both;
        pointer-events: none;
      }

      .alearis-dice-event-banner.leaving {
        animation: alearis-banner-out 260ms ease both;
      }

      .alearis-dice-event-banner__sigil {
        width: 100px;
        height: 100px;
        justify-self: center;
      }

      .alearis-dice-event-banner__title {
        color: ${UI_COLORS.goldBright};
        font: 900 clamp(28px, 2.8vw, 54px) "Palatino Linotype", Georgia, serif;
        letter-spacing: 0.09em;
        line-height: 1;
        text-transform: uppercase;
      }

      .alearis-dice-event-banner__effect {
        margin-top: 8px;
        color: ${UI_COLORS.ivory};
        font: 700 clamp(14px, 1vw, 19px) "Segoe UI", sans-serif;
      }

      .alearis-dice-event-banner.tone-danger {
        border-color: rgba(214, 90, 84, 0.74);
      }

      .alearis-dice-event-banner.tone-divine {
        border-color: rgba(255, 243, 189, 0.82);
      }

      @keyframes alearis-banner-in {
        from { opacity: 0; transform: translate(-50%, -20px) scale(0.98); }
        to { opacity: 1; transform: translate(-50%, 0) scale(1); }
      }

      @keyframes alearis-banner-out {
        from { opacity: 1; transform: translate(-50%, 0) scale(1); }
        to { opacity: 0; transform: translate(-50%, -18px) scale(0.98); }
      }
    `;
    document.head.appendChild(style);
  }
}

function drawBannerSigil(canvas: HTMLCanvasElement, tone: DiceEventBannerPayload['tone']): void {
  const ctx = canvas.getContext('2d');
  if (ctx === null) return;

  const accent = tone === 'danger' ? UI_COLORS.red : tone === 'divine' ? UI_COLORS.divine : UI_COLORS.gold;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.save();
  ctx.translate(66, 66);
  ctx.strokeStyle = accent;
  ctx.fillStyle = 'rgba(214, 174, 84, 0.12)';
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.arc(0, 0, 50, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();

  for (let i = 0; i < 8; i++) {
    const angle = (i / 8) * Math.PI * 2;
    ctx.beginPath();
    ctx.moveTo(Math.cos(angle) * 18, Math.sin(angle) * 18);
    ctx.lineTo(Math.cos(angle) * 54, Math.sin(angle) * 54);
    ctx.stroke();
  }

  ctx.beginPath();
  ctx.moveTo(0, -28);
  ctx.lineTo(28, 0);
  ctx.lineTo(0, 28);
  ctx.lineTo(-28, 0);
  ctx.closePath();
  ctx.strokeStyle = UI_COLORS.goldBright;
  ctx.stroke();
  ctx.restore();
}
