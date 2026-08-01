import type { RelicBand, RelicRarity } from '../../core/types';
import { UI_COLORS, createButton, createPanel, createScreenRoot, installUiTheme, mountElement } from '../UiTheme';

export interface RelicChoiceCard {
  id: string;
  name: string;
  description: string;
  rarity: RelicRarity;
  band: RelicBand;
}

export interface RelicChoiceOptions {
  root?: HTMLElement | string;
  relics?: readonly RelicChoiceCard[];
  roll?: number;
  onChoose?: (relic: RelicChoiceCard) => void;
  onSkip?: () => void;
}

const SAMPLE_RELICS: readonly RelicChoiceCard[] = [
  {
    id: 'sample-marrow',
    name: 'Marrow Lantern',
    description: 'Kills rekindle a small amount of health, rewarding clean routing.',
    rarity: 'COMMON',
    band: 'SURVIVAL',
  },
  {
    id: 'sample-auspice',
    name: 'Heavy Auspice',
    description: 'Loaded fate turns meter gain into pressure with a modest damage lift.',
    rarity: 'RARE',
    band: 'CORE',
  },
  {
    id: 'sample-star',
    name: 'Starvein Core',
    description: 'Each boss DPS window burns longer before the core goes dark.',
    rarity: 'LEGENDARY',
    band: 'CORE',
  },
];

export class RelicChoice {
  readonly element: HTMLDivElement;

  private readonly options: RelicChoiceOptions;
  private relics: readonly RelicChoiceCard[];

  constructor(options: RelicChoiceOptions = {}) {
    installUiTheme();
    this.options = options;
    this.relics = options.relics ?? SAMPLE_RELICS;
    this.element = createScreenRoot('alearis-relic-choice');
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

  setRelics(relics: readonly RelicChoiceCard[]): void {
    this.relics = relics;
    this.element.replaceChildren(this.buildPanel());
  }

  private buildPanel(): HTMLDivElement {
    const panel = createPanel('alearis-relic-choice__panel');
    const rollLine = this.options.roll === undefined ? '' : `<span class="alearis-relic-choice__roll">Victory roll ${this.options.roll}</span>`;
    const header = document.createElement('header');
    header.innerHTML = `
      <div class="alearis-kicker">Relic Offering ${rollLine}</div>
      <h2 class="alearis-title">Claim a Relic</h2>
      <p class="alearis-copy">Choose one run-persistent relic. Slots are scarce, so each selection should alter your route or combat plan.</p>
    `;

    const grid = document.createElement('div');
    grid.className = 'alearis-card-grid alearis-relic-choice__grid';
    grid.style.setProperty('--alearis-card-count', `${Math.max(1, Math.min(4, this.relics.length))}`);
    this.relics.forEach((relic) => grid.appendChild(this.createCard(relic)));

    const footer = document.createElement('footer');
    footer.className = 'alearis-relic-choice__footer';
    footer.appendChild(createButton({ label: 'Leave Relics', variant: 'secondary', onClick: this.options.onSkip }));

    panel.append(header, grid, footer);
    return panel;
  }

  private createCard(relic: RelicChoiceCard): HTMLButtonElement {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = `alearis-panel alearis-card alearis-relic-card rarity-${relic.rarity.toLowerCase()}`;

    const glyph = document.createElement('canvas');
    glyph.width = 160;
    glyph.height = 126;
    glyph.className = 'alearis-relic-card__glyph';
    drawRelicGlyph(glyph, relic.band, relic.rarity);

    card.innerHTML = `
      <div class="alearis-relic-card__glyph-slot"></div>
      <div class="alearis-relic-card__meta">${relic.rarity} / ${formatBand(relic.band)}</div>
      <h3>${relic.name}</h3>
      <p>${relic.description}</p>
    `;
    card.querySelector('.alearis-relic-card__glyph-slot')?.appendChild(glyph);
    card.addEventListener('click', () => this.options.onChoose?.(relic));
    return card;
  }

  private installScreenStyle(): void {
    const id = 'alearis-relic-choice-style';
    if (document.getElementById(id) !== null) return;

    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      .alearis-relic-choice__panel {
        width: min(1480px, 94vw);
        padding: clamp(26px, 3vw, 58px);
      }

      .alearis-relic-choice .alearis-title {
        font-size: clamp(46px, 5vw, 96px);
      }

      .alearis-relic-choice__roll {
        color: ${UI_COLORS.ivory};
      }

      .alearis-relic-choice__grid {
        margin-top: 28px;
      }

      .alearis-relic-card {
        text-align: left;
        cursor: pointer;
        color: inherit;
      }

      .alearis-relic-card:hover {
        border-color: rgba(255, 224, 154, 0.95);
      }

      .alearis-relic-card.rarity-legendary {
        border-color: rgba(255, 224, 154, 0.78);
        box-shadow: 0 0 48px rgba(214, 174, 84, 0.18), inset 0 0 0 1px rgba(255, 224, 154, 0.18);
      }

      .alearis-relic-card__glyph {
        width: 160px;
        height: 126px;
      }

      .alearis-relic-card__meta {
        color: ${UI_COLORS.goldBright};
        font: 800 13px "Cascadia Mono", monospace;
        letter-spacing: 0.16em;
        text-transform: uppercase;
      }

      .alearis-relic-choice__footer {
        display: flex;
        justify-content: flex-end;
        margin-top: 24px;
      }
    `;
    document.head.appendChild(style);
  }
}

function formatBand(band: RelicBand): string {
  return band.replace('_', ' ');
}

function drawRelicGlyph(canvas: HTMLCanvasElement, band: RelicBand, rarity: RelicRarity): void {
  const ctx = canvas.getContext('2d');
  if (ctx === null) return;

  const accent = rarity === 'LEGENDARY' ? UI_COLORS.goldBright : rarity === 'EPIC' ? UI_COLORS.void : UI_COLORS.gold;
  const core = band === 'SURVIVAL' ? UI_COLORS.frost : band === 'GREED_DAMAGE' ? UI_COLORS.red : UI_COLORS.gold;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.save();
  ctx.translate(80, 62);
  ctx.strokeStyle = accent;
  ctx.fillStyle = 'rgba(214, 174, 84, 0.12)';
  ctx.lineWidth = 5;

  ctx.beginPath();
  ctx.moveTo(0, -52);
  ctx.lineTo(48, -14);
  ctx.lineTo(30, 50);
  ctx.lineTo(-30, 50);
  ctx.lineTo(-48, -14);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.strokeStyle = core;
  ctx.beginPath();
  ctx.arc(0, 0, 21, 0, Math.PI * 2);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(-38, 0);
  ctx.lineTo(38, 0);
  ctx.moveTo(0, -38);
  ctx.lineTo(0, 38);
  ctx.stroke();
  ctx.restore();
}
