import { UI_COLORS, createButton, createPanel, createScreenRoot, installUiTheme, mountElement } from '../UiTheme';

export interface PauseSettingsOptions {
  root?: HTMLElement | string;
  musicVolume?: number;
  sfxVolume?: number;
  muted?: boolean;
  onResume?: () => void;
  onMusicVolume?: (volume: number) => void;
  onSfxVolume?: (volume: number) => void;
  onMute?: (muted: boolean) => void;
  onQuit?: () => void;
}

export class PauseSettings {
  readonly element: HTMLDivElement;

  private readonly options: PauseSettingsOptions;
  private musicVolume: number;
  private sfxVolume: number;
  private muted: boolean;

  constructor(options: PauseSettingsOptions = {}) {
    installUiTheme();
    this.options = options;
    this.musicVolume = clampVolume(options.musicVolume ?? 0.72);
    this.sfxVolume = clampVolume(options.sfxVolume ?? 0.86);
    this.muted = options.muted ?? false;
    this.element = createScreenRoot('alearis-pause-settings');
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

  setVolumes(musicVolume: number, sfxVolume: number): void {
    this.musicVolume = clampVolume(musicVolume);
    this.sfxVolume = clampVolume(sfxVolume);
    this.refreshInputs();
  }

  setMuted(muted: boolean): void {
    this.muted = muted;
    this.refreshInputs();
  }

  private buildPanel(): HTMLDivElement {
    const panel = createPanel('alearis-pause-settings__panel');
    const header = document.createElement('header');
    header.innerHTML = `
      <div class="alearis-kicker">Run Paused</div>
      <h2 class="alearis-title">Settings</h2>
      <p class="alearis-copy">Adjust procedural music beds and authored synthesized SFX.</p>
    `;

    const controls = document.createElement('div');
    controls.className = 'alearis-pause-settings__controls';
    controls.append(
      this.createSlider('Music', 'music', this.musicVolume, (value) => {
        this.musicVolume = value;
        this.options.onMusicVolume?.(value);
      }),
      this.createSlider('SFX', 'sfx', this.sfxVolume, (value) => {
        this.sfxVolume = value;
        this.options.onSfxVolume?.(value);
      }),
    );

    const muteRow = document.createElement('label');
    muteRow.className = 'alearis-pause-settings__mute';
    const muteInput = document.createElement('input');
    muteInput.type = 'checkbox';
    muteInput.checked = this.muted;
    muteInput.dataset.setting = 'muted';
    muteInput.addEventListener('change', () => {
      this.muted = muteInput.checked;
      this.options.onMute?.(this.muted);
      this.refreshInputs();
    });
    muteRow.append(muteInput, document.createTextNode('Mute all audio'));

    const actions = document.createElement('div');
    actions.className = 'alearis-pause-settings__actions';
    actions.append(
      createButton({ label: 'Resume', onClick: this.options.onResume }),
      createButton({ label: 'Quit Run', variant: 'danger', onClick: this.options.onQuit }),
    );

    panel.append(header, controls, muteRow, actions);
    return panel;
  }

  private createSlider(label: string, key: 'music' | 'sfx', value: number, onChange: (value: number) => void): HTMLLabelElement {
    const row = document.createElement('label');
    row.className = 'alearis-pause-settings__slider';
    row.innerHTML = `<span>${label}</span><strong>${Math.round(value * 100)}%</strong>`;

    const input = document.createElement('input');
    input.type = 'range';
    input.min = '0';
    input.max = '1';
    input.step = '0.01';
    input.value = `${value}`;
    input.className = 'alearis-range';
    input.dataset.setting = key;
    input.addEventListener('input', () => {
      const next = clampVolume(input.valueAsNumber);
      const readout = row.querySelector('strong');
      if (readout !== null) readout.textContent = `${Math.round(next * 100)}%`;
      onChange(next);
    });

    row.appendChild(input);
    return row;
  }

  private refreshInputs(): void {
    const music = this.element.querySelector<HTMLInputElement>('input[data-setting="music"]');
    const sfx = this.element.querySelector<HTMLInputElement>('input[data-setting="sfx"]');
    const muted = this.element.querySelector<HTMLInputElement>('input[data-setting="muted"]');
    if (music !== null) music.value = `${this.musicVolume}`;
    if (sfx !== null) sfx.value = `${this.sfxVolume}`;
    if (muted !== null) muted.checked = this.muted;

    this.element.querySelectorAll<HTMLLabelElement>('.alearis-pause-settings__slider').forEach((row) => {
      const input = row.querySelector<HTMLInputElement>('input[type="range"]');
      const readout = row.querySelector('strong');
      if (input !== null && readout !== null) {
        readout.textContent = `${Math.round(clampVolume(input.valueAsNumber) * 100)}%`;
      }
    });
  }

  private installScreenStyle(): void {
    const id = 'alearis-pause-settings-style';
    if (document.getElementById(id) !== null) return;

    const style = document.createElement('style');
    style.id = id;
    style.textContent = `
      .alearis-pause-settings__panel {
        width: min(820px, 90vw);
        padding: clamp(30px, 4vw, 62px);
      }

      .alearis-pause-settings .alearis-title {
        font-size: clamp(52px, 5vw, 98px);
      }

      .alearis-pause-settings__controls {
        display: grid;
        gap: 22px;
        margin-top: 32px;
      }

      .alearis-pause-settings__slider {
        display: grid;
        grid-template-columns: 120px 1fr 72px;
        gap: 18px;
        align-items: center;
        color: ${UI_COLORS.ivory};
        font: 800 16px "Cascadia Mono", monospace;
        letter-spacing: 0.12em;
        text-transform: uppercase;
      }

      .alearis-pause-settings__slider input {
        grid-column: 2;
      }

      .alearis-pause-settings__slider strong {
        grid-column: 3;
        color: ${UI_COLORS.goldBright};
        text-align: right;
      }

      .alearis-pause-settings__mute {
        display: inline-flex;
        gap: 12px;
        align-items: center;
        margin-top: 26px;
        color: ${UI_COLORS.muted};
        font: 800 15px "Cascadia Mono", monospace;
        letter-spacing: 0.1em;
        text-transform: uppercase;
      }

      .alearis-pause-settings__mute input {
        width: 22px;
        height: 22px;
        accent-color: ${UI_COLORS.gold};
      }

      .alearis-pause-settings__actions {
        display: flex;
        justify-content: flex-end;
        gap: 14px;
        margin-top: 36px;
      }
    `;
    document.head.appendChild(style);
  }
}

function clampVolume(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}
