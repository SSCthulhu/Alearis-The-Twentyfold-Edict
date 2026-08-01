import { UI_COLORS, createButton, createPanel, createScreenRoot, installUiTheme, mountElement } from '../UiTheme';

export interface MainMenuOptions {
  root?: HTMLElement | string;
  versionText?: string;
  onStart?: () => void;
  onContinue?: () => void;
  onSettings?: () => void;
}

export class MainMenu {
  readonly element: HTMLDivElement;

  constructor(privateOptions: MainMenuOptions = {}) {
    installUiTheme();
    this.element = createScreenRoot('alearis-main-menu');
    this.element.appendChild(this.buildPanel(privateOptions));
    this.installScreenStyle();

    if (privateOptions.root !== undefined) {
      this.mount(privateOptions.root);
    }
  }

  mount(root?: HTMLElement | string): void {
    if (this.element.parentElement !== null) return;
    mountElement(root, this.element);
  }

  unmount(): void {
    this.element.remove();
  }

  show(): void {
    this.element.hidden = false;
  }

  hide(): void {
    this.element.hidden = true;
  }

  private buildPanel(options: MainMenuOptions): HTMLDivElement {
    const panel = createPanel('alearis-main-menu__panel');

    const sigil = document.createElement('canvas');
    sigil.width = 260;
    sigil.height = 260;
    sigil.className = 'alearis-main-menu__sigil';
    drawMainSigil(sigil);

    const copy = document.createElement('div');
    copy.className = 'alearis-main-menu__copy';
    copy.innerHTML = `
      <div class="alearis-kicker">The Twentyfold Edict</div>
      <h1 class="alearis-title">Alearis</h1>
      <p class="alearis-copy">Climb five-floor arenas, carry Ascension Charge under fire, and bargain with a living dice range.</p>
    `;

    const actions = document.createElement('div');
    actions.className = 'alearis-main-menu__actions';
    actions.append(
      createButton({ label: 'Begin Run', onClick: options.onStart }),
      createButton({ label: 'Continue', variant: 'secondary', onClick: options.onContinue }),
      createButton({ label: 'Settings', variant: 'secondary', onClick: options.onSettings }),
    );

    const footer = document.createElement('div');
    footer.className = 'alearis-main-menu__footer';
    footer.textContent = options.versionText ?? 'No external assets - procedural audio and glyph UI';

    panel.append(sigil, copy, actions, footer);
    return panel;
  }

  private installScreenStyle(): void {
    const id = 'alearis-main-menu-style';
    if (document.getElementById(id) !== null) return;

    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      .alearis-main-menu__panel {
        width: min(1180px, 92vw);
        min-height: 640px;
        padding: clamp(34px, 4vw, 74px);
        display: grid;
        grid-template-columns: minmax(220px, 0.62fr) minmax(360px, 1fr);
        gap: clamp(28px, 4vw, 72px);
        align-items: center;
      }

      .alearis-main-menu__sigil {
        width: min(260px, 30vw);
        height: min(260px, 30vw);
        justify-self: center;
        filter: drop-shadow(0 0 34px rgba(214, 174, 84, 0.28));
      }

      .alearis-main-menu__copy .alearis-title {
        font-size: clamp(78px, 9vw, 170px);
        letter-spacing: 0.04em;
      }

      .alearis-main-menu__actions {
        grid-column: 2;
        display: flex;
        flex-wrap: wrap;
        gap: 14px;
        margin-top: 18px;
      }

      .alearis-main-menu__footer {
        grid-column: 1 / -1;
        align-self: end;
        color: rgba(244, 234, 210, 0.58);
        font: 700 13px "Cascadia Mono", monospace;
        letter-spacing: 0.14em;
        text-transform: uppercase;
      }

      @media (max-width: 860px) {
        .alearis-main-menu__panel {
          grid-template-columns: 1fr;
          text-align: center;
        }

        .alearis-main-menu__actions,
        .alearis-main-menu__footer {
          grid-column: auto;
          justify-content: center;
        }
      }
    `;
    document.head.appendChild(style);
  }
}

function drawMainSigil(canvas: HTMLCanvasElement): void {
  const ctx = canvas.getContext('2d');
  if (ctx === null) return;

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.save();
  ctx.translate(130, 130);
  ctx.strokeStyle = UI_COLORS.gold;
  ctx.fillStyle = 'rgba(214, 174, 84, 0.1)';
  ctx.lineWidth = 5;

  for (let ring = 0; ring < 3; ring++) {
    ctx.beginPath();
    ctx.arc(0, 0, 34 + ring * 35, 0, Math.PI * 2);
    ctx.stroke();
  }

  for (let i = 0; i < 20; i++) {
    const angle = -Math.PI * 0.5 + (i / 20) * Math.PI * 2;
    const inner = i % 5 === 0 ? 54 : 78;
    const outer = i % 2 === 0 ? 116 : 104;
    ctx.beginPath();
    ctx.moveTo(Math.cos(angle) * inner, Math.sin(angle) * inner);
    ctx.lineTo(Math.cos(angle) * outer, Math.sin(angle) * outer);
    ctx.stroke();
  }

  ctx.beginPath();
  ctx.moveTo(0, -92);
  ctx.lineTo(80, -22);
  ctx.lineTo(50, 86);
  ctx.lineTo(-50, 86);
  ctx.lineTo(-80, -22);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = UI_COLORS.goldBright;
  ctx.stroke();
  ctx.restore();
}
