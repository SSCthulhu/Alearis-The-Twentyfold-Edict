export interface AudioEngineOptions {
  masterVolume?: number;
  musicVolume?: number;
  sfxVolume?: number;
  autoResumeOnGesture?: boolean;
}

export type AudioBusName = 'master' | 'music' | 'sfx';

interface AudioBusSet {
  master: GainNode;
  music: GainNode;
  sfx: GainNode;
}

interface WebkitAudioWindow extends Window {
  webkitAudioContext?: typeof AudioContext;
}

export class AudioEngine {
  readonly context: AudioContext;
  readonly masterBus: GainNode;
  readonly musicBus: GainNode;
  readonly sfxBus: GainNode;

  private masterVolume: number;
  private musicVolume: number;
  private sfxVolume: number;
  private muted = false;
  private gestureResumeInstalled = false;

  constructor(options: AudioEngineOptions = {}) {
    const AudioCtor = getAudioContextConstructor();
    this.context = new AudioCtor();

    const buses = this.createBuses();
    this.masterBus = buses.master;
    this.musicBus = buses.music;
    this.sfxBus = buses.sfx;

    this.masterVolume = clampVolume(options.masterVolume ?? 1);
    this.musicVolume = clampVolume(options.musicVolume ?? 0.72);
    this.sfxVolume = clampVolume(options.sfxVolume ?? 0.86);
    this.applyVolumes(0);

    if (options.autoResumeOnGesture !== false) {
      this.installGestureResume();
    }
  }

  get isMuted(): boolean {
    return this.muted;
  }

  get currentMusicVolume(): number {
    return this.musicVolume;
  }

  get currentSfxVolume(): number {
    return this.sfxVolume;
  }

  async resume(): Promise<void> {
    if (this.context.state === 'closed') return;
    if (this.context.state === 'suspended') {
      await this.context.resume();
    }
  }

  setMasterVolume(volume: number): void {
    this.masterVolume = clampVolume(volume);
    this.applyVolumes();
  }

  setMusicVolume(volume: number): void {
    this.musicVolume = clampVolume(volume);
    this.applyVolumes();
  }

  setSfxVolume(volume: number): void {
    this.sfxVolume = clampVolume(volume);
    this.applyVolumes();
  }

  mute(muted = true): void {
    this.muted = muted;
    this.applyVolumes();
  }

  bus(name: AudioBusName): GainNode {
    if (name === 'master') return this.masterBus;
    if (name === 'music') return this.musicBus;
    return this.sfxBus;
  }

  now(): number {
    return this.context.currentTime;
  }

  createGain(value = 1): GainNode {
    const gain = this.context.createGain();
    gain.gain.value = value;
    return gain;
  }

  private createBuses(): AudioBusSet {
    const master = this.context.createGain();
    const music = this.context.createGain();
    const sfx = this.context.createGain();

    music.connect(master);
    sfx.connect(master);
    master.connect(this.context.destination);

    return { master, music, sfx };
  }

  private applyVolumes(rampSeconds = 0.025): void {
    const now = this.context.currentTime;
    const masterTarget = this.muted ? 0 : this.masterVolume;
    setGain(this.masterBus.gain, masterTarget, now, rampSeconds);
    setGain(this.musicBus.gain, this.musicVolume, now, rampSeconds);
    setGain(this.sfxBus.gain, this.sfxVolume, now, rampSeconds);
  }

  private installGestureResume(): void {
    if (this.gestureResumeInstalled) return;
    this.gestureResumeInstalled = true;

    const resumeOnce = (): void => {
      window.removeEventListener('pointerdown', resumeOnce);
      window.removeEventListener('keydown', resumeOnce);
      window.removeEventListener('touchstart', resumeOnce);
      void this.resume();
    };

    window.addEventListener('pointerdown', resumeOnce, { passive: true });
    window.addEventListener('keydown', resumeOnce);
    window.addEventListener('touchstart', resumeOnce, { passive: true });
  }
}

export function createAudioEngine(options: AudioEngineOptions = {}): AudioEngine {
  return new AudioEngine(options);
}

function getAudioContextConstructor(): typeof AudioContext {
  const win = window as WebkitAudioWindow;
  const AudioCtor = window.AudioContext ?? win.webkitAudioContext;
  if (AudioCtor === undefined) {
    throw new Error('Web Audio API is not available in this browser.');
  }
  return AudioCtor;
}

function setGain(param: AudioParam, value: number, now: number, rampSeconds: number): void {
  param.cancelScheduledValues(now);
  if (rampSeconds <= 0) {
    param.setValueAtTime(value, now);
    return;
  }
  param.setTargetAtTime(value, now, rampSeconds);
}

function clampVolume(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}
