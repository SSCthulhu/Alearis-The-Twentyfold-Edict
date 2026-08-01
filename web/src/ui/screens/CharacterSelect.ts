import type { ClassId } from '../../core/types';
import { UI_COLORS, createButton, createPanel, createScreenRoot, installUiTheme, mountElement } from '../UiTheme';

export interface CharacterSelectOption {
  id: ClassId;
  name: string;
  role: string;
  description: string;
  locked?: boolean;
}

export interface CharacterSelectOptions {
  root?: HTMLElement | string;
  selected?: ClassId;
  onSelect?: (classId: Exclude<ClassId, 'mage'>) => void;
  onBack?: () => void;
}

const CHARACTERS: readonly CharacterSelectOption[] = [
  {
    id: 'knight',
    name: 'Knight',
    role: 'Shielded Vanguard',
    description: 'Wide guard arcs, deliberate burst windows, and reliable Ascension Charge carries.',
  },
  {
    id: 'rogue',
    name: 'Rogue',
    role: 'Tempo Duelist',
    description: 'Fast cancels, riskier spacing, and extra value from perfect dodge chimes.',
  },
  {
    id: 'mage',
    name: 'Mage',
    role: 'Locked Preview',
    description: 'A future spell-weaver focused on meter manipulation and arena control.',
    locked: true,
  },
];

export class CharacterSelect {
  readonly element: HTMLDivElement;

  private selected: ClassId;

  constructor(options: CharacterSelectOptions = {}) {
    installUiTheme();
    this.selected = options.selected ?? 'knight';
    this.element = createScreenRoot('alearis-character-select');
    this.element.appendChild(this.buildPanel(options));
    this.installScreenStyle();
    this.refreshCards();

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

  setSelected(classId: ClassId): void {
    this.selected = classId;
    this.refreshCards();
  }

  private buildPanel(options: CharacterSelectOptions): HTMLDivElement {
    const panel = createPanel('alearis-character-select__panel');
    const header = document.createElement('header');
    header.innerHTML = `
      <div class="alearis-kicker">Choose your vessel</div>
      <h2 class="alearis-title">Character Select</h2>
      <p class="alearis-copy">Two classes are playable now. The Mage is shown as a locked systems preview.</p>
    `;

    const grid = document.createElement('div');
    grid.className = 'alearis-card-grid alearis-character-select__grid';
    grid.style.setProperty('--alearis-card-count', '3');

    for (const character of CHARACTERS) {
      grid.appendChild(this.createCard(character, options));
    }

    const footer = document.createElement('footer');
    footer.className = 'alearis-character-select__footer';
    footer.appendChild(createButton({ label: 'Back', variant: 'secondary', onClick: options.onBack }));

    panel.append(header, grid, footer);
    return panel;
  }

  private createCard(character: CharacterSelectOption, options: CharacterSelectOptions): HTMLButtonElement {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'alearis-panel alearis-card alearis-character-card';
    button.dataset.classId = character.id;
    button.disabled = character.locked === true;

    const glyph = document.createElement('canvas');
    glyph.width = 180;
    glyph.height = 128;
    glyph.className = 'alearis-character-card__glyph';
    drawCharacterGlyph(glyph, character.id);

    const lock = character.locked === true ? '<div class="alearis-character-card__lock">Locked</div>' : '';
    button.innerHTML = `
      ${lock}
      <div class="alearis-character-card__glyph-slot"></div>
      <div class="alearis-kicker">${character.role}</div>
      <h3>${character.name}</h3>
      <p>${character.description}</p>
    `;
    button.querySelector('.alearis-character-card__glyph-slot')?.appendChild(glyph);

    if (character.locked !== true) {
      button.addEventListener('click', () => {
        this.selected = character.id;
        this.refreshCards();
        options.onSelect?.(character.id as Exclude<ClassId, 'mage'>);
      });
    }

    return button;
  }

  private refreshCards(): void {
    const cards = this.element.querySelectorAll<HTMLButtonElement>('.alearis-character-card');
    cards.forEach((card) => {
      card.classList.toggle('selected', card.dataset.classId === this.selected);
    });
  }

  private installScreenStyle(): void {
    const id = 'alearis-character-select-style';
    if (document.getElementById(id) !== null) return;

    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      .alearis-character-select__panel {
        width: min(1460px, 94vw);
        padding: clamp(28px, 3vw, 58px);
      }

      .alearis-character-select .alearis-title {
        font-size: clamp(48px, 5vw, 96px);
      }

      .alearis-character-select__grid {
        margin-top: clamp(24px, 2vw, 38px);
      }

      .alearis-character-card {
        border: 1px solid rgba(255, 224, 154, 0.34);
        text-align: left;
        cursor: pointer;
        color: inherit;
      }

      .alearis-character-card.selected {
        border-color: rgba(255, 224, 154, 0.95);
        box-shadow: 0 0 44px rgba(214, 174, 84, 0.22), inset 0 0 0 1px rgba(255, 224, 154, 0.32);
      }

      .alearis-character-card:disabled {
        cursor: not-allowed;
        opacity: 0.58;
      }

      .alearis-character-card__glyph {
        width: 180px;
        max-width: 100%;
        height: auto;
      }

      .alearis-character-card__lock {
        position: absolute;
        top: 18px;
        right: 18px;
        padding: 7px 10px;
        border: 1px solid rgba(214, 90, 84, 0.8);
        color: ${UI_COLORS.red};
        font: 800 12px "Cascadia Mono", monospace;
        letter-spacing: 0.16em;
        text-transform: uppercase;
      }

      .alearis-character-select__footer {
        display: flex;
        justify-content: flex-end;
        margin-top: 24px;
      }
    `;
    document.head.appendChild(style);
  }
}

function drawCharacterGlyph(canvas: HTMLCanvasElement, classId: ClassId): void {
  const ctx = canvas.getContext('2d');
  if (ctx === null) return;

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.save();
  ctx.translate(90, 66);
  ctx.strokeStyle = classId === 'mage' ? UI_COLORS.void : UI_COLORS.gold;
  ctx.fillStyle = 'rgba(214, 174, 84, 0.14)';
  ctx.lineWidth = 5;

  if (classId === 'knight') {
    ctx.beginPath();
    ctx.moveTo(0, -54);
    ctx.lineTo(46, -28);
    ctx.lineTo(32, 42);
    ctx.lineTo(0, 58);
    ctx.lineTo(-32, 42);
    ctx.lineTo(-46, -28);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(0, -42);
    ctx.lineTo(0, 42);
    ctx.stroke();
  } else if (classId === 'rogue') {
    ctx.beginPath();
    ctx.moveTo(-54, 34);
    ctx.lineTo(8, -48);
    ctx.lineTo(26, -28);
    ctx.lineTo(-20, 48);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(22, 42);
    ctx.lineTo(54, -26);
    ctx.stroke();
  } else {
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.ellipse(0, 0, 56, 18, (Math.PI / 3) * i, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.beginPath();
    ctx.arc(0, 0, 12, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.restore();
}
