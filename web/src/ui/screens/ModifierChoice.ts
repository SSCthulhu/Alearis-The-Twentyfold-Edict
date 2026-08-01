import type { DiceDelta } from '../../core/types';
import { UI_COLORS, createButton, createPanel, createScreenRoot, installUiTheme, mountElement } from '../UiTheme';

export interface ModifierChoiceCard {
  id: string;
  name: string;
  description: string;
  delta: DiceDelta;
}

export interface ModifierChoiceOptions {
  root?: HTMLElement | string;
  modifiers?: readonly ModifierChoiceCard[];
  title?: string;
  onChoose?: (modifier: ModifierChoiceCard) => void;
  onSkip?: () => void;
}

const SAMPLE_MODIFIERS: readonly ModifierChoiceCard[] = [
  { id: 'sample-heal', name: 'Hearth of Kallos', description: 'Restore health without changing the dice range.', delta: 0 },
  { id: 'sample-low', name: 'Low-Gravity Psalm', description: 'Softer arcs and easier recoveries for the next floor.', delta: -1 },
  { id: 'sample-mercy', name: 'Winter Court Decree', description: 'Enemies lose health under a pale frost mandate.', delta: -2 },
  { id: 'sample-risk', name: 'Blood-Gold Tax', description: 'Incoming damage rises, but reward rolls open wider.', delta: 1 },
  { id: 'sample-greed', name: 'Meteoric Edict', description: 'Faster hazards, richer outcomes, and a wider fate band.', delta: 2 },
];

export class ModifierChoice {
  readonly element: HTMLDivElement;

  private readonly options: ModifierChoiceOptions;
  private modifiers: readonly ModifierChoiceCard[];

  constructor(options: ModifierChoiceOptions = {}) {
    installUiTheme();
    this.options = options;
    this.modifiers = options.modifiers ?? SAMPLE_MODIFIERS;
    this.element = createScreenRoot('alearis-modifier-choice');
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

  setModifiers(modifiers: readonly ModifierChoiceCard[]): void {
    this.modifiers = modifiers;
    this.element.replaceChildren(this.buildPanel());
  }

  private buildPanel(): HTMLDivElement {
    const panel = createPanel('alearis-modifier-choice__panel');
    const header = document.createElement('header');
    header.innerHTML = `
      <div class="alearis-kicker">Council Bargain</div>
      <h2 class="alearis-title">${this.options.title ?? 'Choose a Modifier'}</h2>
      <p class="alearis-copy">Five edicts reshape the run. Negative deltas stabilize the dice; positive deltas court danger and reward.</p>
    `;

    const grid = document.createElement('div');
    grid.className = 'alearis-card-grid alearis-modifier-choice__grid';
    grid.style.setProperty('--alearis-card-count', '5');
    this.modifiers.slice(0, 5).forEach((modifier) => grid.appendChild(this.createCard(modifier)));

    const footer = document.createElement('footer');
    footer.className = 'alearis-modifier-choice__footer';
    footer.appendChild(createButton({ label: 'Skip Offering', variant: 'secondary', onClick: this.options.onSkip }));

    panel.append(header, grid, footer);
    return panel;
  }

  private createCard(modifier: ModifierChoiceCard): HTMLButtonElement {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = `alearis-panel alearis-card alearis-modifier-card ${deltaClass(modifier.delta)}`;

    const glyph = document.createElement('canvas');
    glyph.width = 128;
    glyph.height = 96;
    glyph.className = 'alearis-modifier-card__glyph';
    drawDiceGlyph(glyph, modifier.delta);

    card.innerHTML = `
      <span class="alearis-modifier-card__delta">${formatDelta(modifier.delta)}</span>
      <div class="alearis-modifier-card__glyph-slot"></div>
      <h3>${modifier.name}</h3>
      <p>${modifier.description}</p>
    `;
    card.querySelector('.alearis-modifier-card__glyph-slot')?.appendChild(glyph);
    card.addEventListener('click', () => this.options.onChoose?.(modifier));
    return card;
  }

  private installScreenStyle(): void {
    const id = 'alearis-modifier-choice-style';
    if (document.getElementById(id) !== null) return;

    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      .alearis-modifier-choice__panel {
        width: min(1840px, 96vw);
        padding: clamp(24px, 2.8vw, 54px);
      }

      .alearis-modifier-choice .alearis-title {
        font-size: clamp(42px, 4.4vw, 84px);
      }

      .alearis-modifier-choice__grid {
        margin-top: 28px;
      }

      .alearis-modifier-card {
        border: 1px solid rgba(255, 224, 154, 0.34);
        color: inherit;
        text-align: left;
        cursor: pointer;
      }

      .alearis-modifier-card:hover {
        border-color: rgba(255, 224, 154, 0.95);
      }

      .alearis-modifier-card.positive {
        border-color: rgba(214, 90, 84, 0.55);
      }

      .alearis-modifier-card.negative {
        border-color: rgba(127, 182, 217, 0.55);
      }

      .alearis-modifier-card__delta {
        position: absolute;
        top: 18px;
        right: 18px;
        min-width: 48px;
        padding: 8px 10px;
        border: 1px solid currentColor;
        color: ${UI_COLORS.goldBright};
        text-align: center;
        font: 900 16px "Cascadia Mono", monospace;
      }

      .alearis-modifier-card.positive .alearis-modifier-card__delta {
        color: ${UI_COLORS.red};
      }

      .alearis-modifier-card.negative .alearis-modifier-card__delta {
        color: ${UI_COLORS.frost};
      }

      .alearis-modifier-card__glyph {
        width: 128px;
        height: 96px;
      }

      .alearis-modifier-choice__footer {
        display: flex;
        justify-content: flex-end;
        margin-top: 24px;
      }
    `;
    document.head.appendChild(style);
  }
}

function formatDelta(delta: DiceDelta): string {
  if (delta > 0) return `+${delta}`;
  return `${delta}`;
}

function deltaClass(delta: DiceDelta): string {
  if (delta > 0) return 'positive';
  if (delta < 0) return 'negative';
  return 'neutral';
}

function drawDiceGlyph(canvas: HTMLCanvasElement, delta: DiceDelta): void {
  const ctx = canvas.getContext('2d');
  if (ctx === null) return;

  const accent = delta > 0 ? UI_COLORS.red : delta < 0 ? UI_COLORS.frost : UI_COLORS.gold;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.save();
  ctx.translate(64, 48);
  ctx.rotate(-0.12);
  ctx.fillStyle = 'rgba(8, 10, 17, 0.9)';
  ctx.strokeStyle = accent;
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.roundRect(-38, -38, 76, 76, 12);
  ctx.fill();
  ctx.stroke();

  const pipCount = Math.max(1, Math.min(5, Math.abs(delta) + 3));
  for (let i = 0; i < pipCount; i++) {
    const angle = (i / pipCount) * Math.PI * 2;
    const radius = pipCount === 1 ? 0 : 20;
    ctx.beginPath();
    ctx.arc(Math.cos(angle) * radius, Math.sin(angle) * radius, 5, 0, Math.PI * 2);
    ctx.fillStyle = accent;
    ctx.fill();
  }

  ctx.restore();
}
