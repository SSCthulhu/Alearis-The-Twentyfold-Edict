import type { RelicBand } from '../../core/types';
import { UI_COLORS, createButton, createPanel, createScreenRoot, installUiTheme, mountElement } from '../UiTheme';

export interface VictoryRollResult {
  roll: number;
  band: RelicBand;
}

export interface VictoryRollOptions {
  root?: HTMLElement | string;
  result?: VictoryRollResult;
  onRoll?: () => void;
  onContinue?: (result: VictoryRollResult) => void;
}

const DEFAULT_RESULT: VictoryRollResult = {
  roll: 12,
  band: 'CORE',
};

export class VictoryRoll {
  readonly element: HTMLDivElement;

  private readonly options: VictoryRollOptions;
  private result: VictoryRollResult;
  private dieCanvas: HTMLCanvasElement | null = null;

  constructor(options: VictoryRollOptions = {}) {
    installUiTheme();
    this.options = options;
    this.result = options.result ?? DEFAULT_RESULT;
    this.element = createScreenRoot('alearis-victory-roll');
    this.element.appendChild(this.buildPanel());
    this.installScreenStyle();
    this.paintDie();

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

  setResult(result: VictoryRollResult): void {
    this.result = result;
    this.refreshText();
    this.paintDie();
  }

  private buildPanel(): HTMLDivElement {
    const panel = createPanel('alearis-victory-roll__panel');
    const header = document.createElement('header');
    header.innerHTML = `
      <div class="alearis-kicker">Floor Cleared</div>
      <h2 class="alearis-title">Victory Roll</h2>
      <p class="alearis-copy">The dice chooses which relic band answers your ascent.</p>
    `;

    this.dieCanvas = document.createElement('canvas');
    this.dieCanvas.width = 340;
    this.dieCanvas.height = 260;
    this.dieCanvas.className = 'alearis-victory-roll__die';

    const readout = document.createElement('div');
    readout.className = 'alearis-victory-roll__readout';
    readout.innerHTML = this.resultMarkup();

    const actions = document.createElement('div');
    actions.className = 'alearis-victory-roll__actions';
    actions.append(
      createButton({ label: 'Roll Again FX', variant: 'secondary', onClick: this.options.onRoll }),
      createButton({ label: 'Choose Relic', onClick: () => this.options.onContinue?.(this.result) }),
    );

    panel.append(header, this.dieCanvas, readout, actions);
    return panel;
  }

  private refreshText(): void {
    const readout = this.element.querySelector<HTMLDivElement>('.alearis-victory-roll__readout');
    if (readout !== null) readout.innerHTML = this.resultMarkup();
  }

  private resultMarkup(): string {
    return `
      <div class="alearis-victory-roll__number">${this.result.roll}</div>
      <div class="alearis-victory-roll__band">${this.result.band.replace('_', ' ')}</div>
    `;
  }

  private paintDie(): void {
    if (this.dieCanvas === null) return;
    const ctx = this.dieCanvas.getContext('2d');
    if (ctx === null) return;

    ctx.clearRect(0, 0, this.dieCanvas.width, this.dieCanvas.height);
    ctx.save();
    ctx.translate(170, 130);
    ctx.rotate(-0.08);
    ctx.fillStyle = 'rgba(8, 10, 17, 0.94)';
    ctx.strokeStyle = UI_COLORS.gold;
    ctx.lineWidth = 7;
    ctx.beginPath();
    ctx.roundRect(-96, -96, 192, 192, 24);
    ctx.fill();
    ctx.stroke();

    const pipCount = Math.max(1, Math.min(20, this.result.roll));
    const radius = 62;
    for (let i = 0; i < pipCount; i++) {
      const angle = -Math.PI * 0.5 + (i / pipCount) * Math.PI * 2;
      const inner = i % 2 === 0 ? radius : radius * 0.62;
      ctx.beginPath();
      ctx.arc(Math.cos(angle) * inner, Math.sin(angle) * inner, 5.5, 0, Math.PI * 2);
      ctx.fillStyle = bandColor(this.result.band);
      ctx.fill();
    }

    ctx.font = '900 58px "Cascadia Mono", monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = UI_COLORS.ivory;
    ctx.fillText(`${this.result.roll}`, 0, 0);
    ctx.restore();
  }

  private installScreenStyle(): void {
    const id = 'alearis-victory-roll-style';
    if (document.getElementById(id) !== null) return;

    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      .alearis-victory-roll__panel {
        width: min(980px, 92vw);
        padding: clamp(30px, 4vw, 70px);
        display: grid;
        grid-template-columns: 340px minmax(260px, 1fr);
        gap: clamp(22px, 4vw, 58px);
        align-items: center;
      }

      .alearis-victory-roll__panel header,
      .alearis-victory-roll__actions {
        grid-column: 1 / -1;
      }

      .alearis-victory-roll .alearis-title {
        font-size: clamp(54px, 6vw, 112px);
      }

      .alearis-victory-roll__die {
        width: 340px;
        max-width: 100%;
        height: auto;
        filter: drop-shadow(0 0 38px rgba(214, 174, 84, 0.24));
      }

      .alearis-victory-roll__number {
        color: ${UI_COLORS.goldBright};
        font: 900 clamp(90px, 12vw, 188px) "Cascadia Mono", monospace;
        line-height: 0.9;
      }

      .alearis-victory-roll__band {
        color: ${UI_COLORS.ivory};
        font: 900 clamp(24px, 2.2vw, 42px) "Palatino Linotype", Georgia, serif;
        letter-spacing: 0.12em;
        text-transform: uppercase;
      }

      .alearis-victory-roll__actions {
        display: flex;
        justify-content: flex-end;
        gap: 14px;
      }
    `;
    document.head.appendChild(style);
  }
}

function bandColor(band: RelicBand): string {
  if (band === 'SURVIVAL') return UI_COLORS.frost;
  if (band === 'GREED_DAMAGE') return UI_COLORS.red;
  return UI_COLORS.goldBright;
}
