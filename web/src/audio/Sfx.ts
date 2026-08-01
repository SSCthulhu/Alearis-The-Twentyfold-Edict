import { AudioEngine } from './AudioEngine';

export type SfxName =
  | 'combatHit'
  | 'arcaneBolt'
  | 'frostNova'
  | 'arcaneBarrier'
  | 'arcaneStorm'
  | 'perfectDodgeChime'
  | 'rollDashWhoosh'
  | 'orbPickup'
  | 'chargeHum'
  | 'socketDeliverySting'
  | 'bossCastTell'
  | 'diceRollStinger'
  | 'councilMotif'
  | 'divineMotif'
  | 'uiTick'
  | 'jump'
  | 'land'
  | 'heal'
  | 'death';

export interface SfxPlayOptions {
  intensity?: number;
  pitch?: number;
}

export interface LoopingSfxHandle {
  stop: () => void;
}

interface Envelope {
  attack: number;
  decay: number;
  sustain: number;
  hold: number;
  release: number;
  peak: number;
}

interface ToneSpec {
  frequency: number;
  start: number;
  duration: number;
  type: OscillatorType;
  gain: number;
  destination: AudioNode;
  detune?: number;
  endFrequency?: number;
  filterType?: BiquadFilterType;
  filterFrequency?: number;
  envelope?: Partial<Envelope>;
}

const DEFAULT_ENVELOPE: Envelope = {
  attack: 0.006,
  decay: 0.06,
  sustain: 0.54,
  hold: 0.04,
  release: 0.08,
  peak: 1,
};

const noiseBuffers = new WeakMap<AudioContext, AudioBuffer>();

export class Sfx {
  private readonly engine: AudioEngine;

  constructor(engine: AudioEngine) {
    this.engine = engine;
  }

  play(name: SfxName, options: SfxPlayOptions = {}): void {
    switch (name) {
      case 'combatHit':
        this.combatHit(options.intensity);
        return;
      case 'arcaneBolt':
        this.arcaneBolt();
        return;
      case 'frostNova':
        this.frostNova();
        return;
      case 'arcaneBarrier':
        this.arcaneBarrier();
        return;
      case 'arcaneStorm':
        this.arcaneStorm();
        return;
      case 'perfectDodgeChime':
        this.perfectDodgeChime();
        return;
      case 'rollDashWhoosh':
        this.rollDashWhoosh(options.intensity);
        return;
      case 'orbPickup':
        this.orbPickup();
        return;
      case 'chargeHum':
        this.chargeHum(1.4);
        return;
      case 'socketDeliverySting':
        this.socketDeliverySting();
        return;
      case 'bossCastTell':
        this.bossCastTell();
        return;
      case 'diceRollStinger':
        this.diceRollStinger();
        return;
      case 'councilMotif':
        this.councilMotif();
        return;
      case 'divineMotif':
        this.divineMotif();
        return;
      case 'uiTick':
        this.uiTick(options.pitch);
        return;
      case 'jump':
        this.jump();
        return;
      case 'land':
        this.land(options.intensity);
        return;
      case 'heal':
        this.heal();
        return;
      case 'death':
        this.death();
        return;
    }
  }

  combatHit(intensity = 1): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    const amount = clamp01(intensity);
    playNoise(ctx, this.engine.sfxBus, {
      start: now,
      duration: 0.16,
      gain: 0.36 + amount * 0.28,
      filterType: 'bandpass',
      filterFrequency: 620,
      envelope: { attack: 0.001, decay: 0.035, hold: 0.015, release: 0.1, peak: 1 },
    });
    scheduleTone(ctx, {
      frequency: 132,
      endFrequency: 62,
      start: now,
      duration: 0.22,
      type: 'sawtooth',
      gain: 0.16 + amount * 0.16,
      destination: this.engine.sfxBus,
      filterType: 'lowpass',
      filterFrequency: 820,
      envelope: { attack: 0.002, decay: 0.045, hold: 0.02, release: 0.16 },
    });
  }

  arcaneBolt(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [440, 880].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        endFrequency: frequency * 1.7,
        start: now + index * 0.012,
        duration: 0.16,
        type: index === 0 ? 'triangle' : 'sine',
        gain: index === 0 ? 0.13 : 0.08,
        destination: this.engine.sfxBus,
        filterType: 'highpass',
        filterFrequency: 360,
        envelope: { attack: 0.002, decay: 0.04, sustain: 0.28, hold: 0.01, release: 0.08 },
      });
    });
  }

  frostNova(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    playNoise(ctx, this.engine.sfxBus, {
      start: now,
      duration: 0.34,
      gain: 0.18,
      filterType: 'highpass',
      filterFrequency: 2400,
      envelope: { attack: 0.004, decay: 0.08, sustain: 0.4, hold: 0.04, release: 0.2 },
    });
    [523.25, 783.99, 1046.5].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        endFrequency: frequency * 0.72,
        start: now + index * 0.018,
        duration: 0.36,
        type: 'sine',
        gain: 0.1,
        destination: this.engine.sfxBus,
        envelope: { attack: 0.006, decay: 0.08, sustain: 0.35, hold: 0.04, release: 0.2 },
      });
    });
  }

  arcaneBarrier(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [293.66, 440, 587.33].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        start: now + index * 0.025,
        duration: 0.52,
        type: 'sine',
        gain: 0.1,
        destination: this.engine.sfxBus,
        envelope: { attack: 0.018, decay: 0.1, sustain: 0.5, hold: 0.08, release: 0.26 },
      });
    });
  }

  arcaneStorm(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    playNoise(ctx, this.engine.sfxBus, {
      start: now,
      duration: 0.68,
      gain: 0.16,
      filterType: 'bandpass',
      filterFrequency: 720,
      envelope: { attack: 0.03, decay: 0.12, sustain: 0.62, hold: 0.18, release: 0.32 },
    });
    [146.83, 220, 440, 659.25].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        endFrequency: frequency * 1.3,
        start: now + index * 0.045,
        duration: 0.62,
        type: index < 2 ? 'sawtooth' : 'triangle',
        gain: index < 2 ? 0.09 : 0.11,
        destination: this.engine.sfxBus,
        filterType: 'lowpass',
        filterFrequency: 2600,
        envelope: { attack: 0.025, decay: 0.12, sustain: 0.5, hold: 0.12, release: 0.28 },
      });
    });
  }

  perfectDodgeChime(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [880, 1320, 1760].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        start: now + index * 0.045,
        duration: 0.32,
        type: 'sine',
        gain: 0.16,
        destination: this.engine.sfxBus,
        filterType: 'highpass',
        filterFrequency: 520,
        envelope: { attack: 0.003, decay: 0.08, sustain: 0.32, hold: 0.04, release: 0.18 },
      });
    });
  }

  rollDashWhoosh(intensity = 1): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    const filter = ctx.createBiquadFilter();
    filter.type = 'highpass';
    filter.frequency.setValueAtTime(240, now);
    filter.frequency.exponentialRampToValueAtTime(1800, now + 0.18);
    filter.connect(this.engine.sfxBus);
    playNoise(ctx, filter, {
      start: now,
      duration: 0.26,
      gain: 0.24 + clamp01(intensity) * 0.18,
      filterType: 'lowpass',
      filterFrequency: 5800,
      envelope: { attack: 0.008, decay: 0.04, sustain: 0.7, hold: 0.07, release: 0.13 },
    });
    scheduleTone(ctx, {
      frequency: 280,
      endFrequency: 110,
      start: now,
      duration: 0.18,
      type: 'triangle',
      gain: 0.08,
      destination: this.engine.sfxBus,
      envelope: { attack: 0.004, decay: 0.04, hold: 0.02, release: 0.09 },
    });
  }

  orbPickup(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [392, 587.33, 784, 1174.66].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        start: now + index * 0.045,
        duration: 0.34,
        type: index % 2 === 0 ? 'triangle' : 'sine',
        gain: 0.12,
        destination: this.engine.sfxBus,
        filterType: 'lowpass',
        filterFrequency: 2600,
        envelope: { attack: 0.005, decay: 0.08, sustain: 0.42, hold: 0.03, release: 0.2 },
      });
    });
  }

  chargeHum(duration = 1.4): void {
    const handle = this.startChargeHum();
    window.setTimeout(handle.stop, Math.max(80, duration * 1000));
  }

  startChargeHum(): LoopingSfxHandle {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    const output = ctx.createGain();
    output.gain.setValueAtTime(0.0001, now);
    output.gain.exponentialRampToValueAtTime(0.22, now + 0.08);
    output.connect(this.engine.sfxBus);

    const lfo = ctx.createOscillator();
    const lfoGain = ctx.createGain();
    lfo.type = 'sine';
    lfo.frequency.value = 5.6;
    lfoGain.gain.value = 0.08;
    lfo.connect(lfoGain);
    lfoGain.connect(output.gain);
    lfo.start(now);

    const oscillators = [73.42, 110, 146.83].map((frequency, index) => {
      const osc = ctx.createOscillator();
      osc.type = index === 1 ? 'triangle' : 'sawtooth';
      osc.frequency.value = frequency;
      osc.detune.value = index === 0 ? -7 : index === 2 ? 9 : 0;
      osc.connect(output);
      osc.start(now);
      return osc;
    });

    return {
      stop: () => {
        const stopAt = ctx.currentTime + 0.18;
        output.gain.cancelScheduledValues(ctx.currentTime);
        output.gain.setTargetAtTime(0.0001, ctx.currentTime, 0.045);
        oscillators.forEach((osc) => osc.stop(stopAt));
        lfo.stop(stopAt);
        window.setTimeout(() => output.disconnect(), 240);
      },
    };
  }

  socketDeliverySting(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [261.63, 392, 523.25, 783.99].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        start: now + index * 0.015,
        duration: 0.58,
        type: 'triangle',
        gain: 0.16,
        destination: this.engine.sfxBus,
        filterType: 'lowpass',
        filterFrequency: 4200,
        envelope: { attack: 0.008, decay: 0.12, sustain: 0.44, hold: 0.08, release: 0.28 },
      });
    });
    playNoise(ctx, this.engine.sfxBus, {
      start: now,
      duration: 0.34,
      gain: 0.12,
      filterType: 'highpass',
      filterFrequency: 4600,
      envelope: { attack: 0.002, decay: 0.06, sustain: 0.2, hold: 0.02, release: 0.18 },
    });
  }

  bossCastTell(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [185, 196, 277.18].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        endFrequency: frequency * 1.18,
        start: now + index * 0.025,
        duration: 0.9,
        type: 'sawtooth',
        gain: 0.14,
        destination: this.engine.sfxBus,
        filterType: 'bandpass',
        filterFrequency: 720 + index * 180,
        envelope: { attack: 0.035, decay: 0.16, sustain: 0.72, hold: 0.25, release: 0.28 },
      });
    });
  }

  diceRollStinger(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    for (let i = 0; i < 7; i++) {
      this.uiTick(1 + i * 0.08, now + i * 0.035);
    }
    [329.63, 415.3, 554.37, 659.25].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        start: now + 0.28 + index * 0.02,
        duration: 0.42,
        type: 'triangle',
        gain: 0.13,
        destination: this.engine.sfxBus,
        envelope: { attack: 0.006, decay: 0.08, sustain: 0.36, hold: 0.03, release: 0.22 },
      });
    });
  }

  councilMotif(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [196, 207.65, 277.18, 261.63, 185].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        start: now + index * 0.12,
        duration: 0.44,
        type: index % 2 === 0 ? 'sawtooth' : 'square',
        gain: 0.11,
        destination: this.engine.sfxBus,
        filterType: 'lowpass',
        filterFrequency: 1400,
        envelope: { attack: 0.012, decay: 0.08, sustain: 0.52, hold: 0.08, release: 0.24 },
      });
    });
  }

  divineMotif(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [523.25, 659.25, 783.99, 1046.5].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        start: now + index * 0.105,
        duration: 0.52,
        type: 'sine',
        gain: 0.14,
        destination: this.engine.sfxBus,
        filterType: 'highpass',
        filterFrequency: 380,
        envelope: { attack: 0.004, decay: 0.1, sustain: 0.42, hold: 0.06, release: 0.28 },
      });
    });
  }

  uiTick(pitch = 1, startTime?: number): void {
    const ctx = this.engine.context;
    const start = startTime ?? ctx.currentTime;
    scheduleTone(ctx, {
      frequency: 760 * Math.max(0.5, pitch),
      start,
      duration: 0.07,
      type: 'square',
      gain: 0.055,
      destination: this.engine.sfxBus,
      filterType: 'highpass',
      filterFrequency: 520,
      envelope: { attack: 0.001, decay: 0.018, sustain: 0.2, hold: 0.006, release: 0.035 },
    });
  }

  jump(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    scheduleTone(ctx, {
      frequency: 164,
      endFrequency: 330,
      start: now,
      duration: 0.18,
      type: 'triangle',
      gain: 0.13,
      destination: this.engine.sfxBus,
      filterType: 'lowpass',
      filterFrequency: 1800,
      envelope: { attack: 0.003, decay: 0.05, sustain: 0.38, hold: 0.02, release: 0.1 },
    });
  }

  land(intensity = 1): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    playNoise(ctx, this.engine.sfxBus, {
      start: now,
      duration: 0.13,
      gain: 0.18 + clamp01(intensity) * 0.18,
      filterType: 'lowpass',
      filterFrequency: 360,
      envelope: { attack: 0.001, decay: 0.035, sustain: 0.1, hold: 0.01, release: 0.08 },
    });
    scheduleTone(ctx, {
      frequency: 84,
      endFrequency: 52,
      start: now,
      duration: 0.16,
      type: 'sine',
      gain: 0.12,
      destination: this.engine.sfxBus,
      envelope: { attack: 0.001, decay: 0.045, sustain: 0.22, hold: 0.02, release: 0.09 },
    });
  }

  heal(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [329.63, 493.88, 659.25, 987.77].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        start: now + index * 0.06,
        duration: 0.46,
        type: 'sine',
        gain: 0.11,
        destination: this.engine.sfxBus,
        filterType: 'lowpass',
        filterFrequency: 3200,
        envelope: { attack: 0.012, decay: 0.08, sustain: 0.44, hold: 0.05, release: 0.24 },
      });
    });
  }

  death(): void {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    [220, 164.81, 110, 73.42].forEach((frequency, index) => {
      scheduleTone(ctx, {
        frequency,
        endFrequency: frequency * 0.72,
        start: now + index * 0.12,
        duration: 0.86,
        type: 'sawtooth',
        gain: 0.14,
        destination: this.engine.sfxBus,
        filterType: 'lowpass',
        filterFrequency: 900,
        envelope: { attack: 0.018, decay: 0.16, sustain: 0.56, hold: 0.18, release: 0.42 },
      });
    });
    playNoise(ctx, this.engine.sfxBus, {
      start: now + 0.08,
      duration: 0.7,
      gain: 0.1,
      filterType: 'bandpass',
      filterFrequency: 290,
      envelope: { attack: 0.02, decay: 0.14, sustain: 0.45, hold: 0.12, release: 0.42 },
    });
  }
}

function scheduleTone(ctx: AudioContext, spec: ToneSpec): void {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  const envelope = { ...DEFAULT_ENVELOPE, ...spec.envelope };
  const destination = createFilteredDestination(ctx, spec.destination, spec.filterType, spec.filterFrequency);

  osc.type = spec.type;
  osc.frequency.setValueAtTime(Math.max(1, spec.frequency), spec.start);
  if (spec.endFrequency !== undefined) {
    osc.frequency.exponentialRampToValueAtTime(Math.max(1, spec.endFrequency), spec.start + spec.duration);
  }
  if (spec.detune !== undefined) osc.detune.value = spec.detune;

  applyEnvelope(gain.gain, spec.start, spec.duration, spec.gain, envelope);
  osc.connect(gain);
  gain.connect(destination);
  osc.start(spec.start);
  osc.stop(spec.start + spec.duration + envelope.release + 0.04);
  osc.onended = () => {
    osc.disconnect();
    gain.disconnect();
    if (destination !== spec.destination) destination.disconnect();
  };
}

function playNoise(
  ctx: AudioContext,
  destination: AudioNode,
  spec: {
    start: number;
    duration: number;
    gain: number;
    filterType: BiquadFilterType;
    filterFrequency: number;
    envelope: Partial<Envelope>;
  },
): void {
  const source = ctx.createBufferSource();
  const gain = ctx.createGain();
  const filter = ctx.createBiquadFilter();
  const envelope = { ...DEFAULT_ENVELOPE, ...spec.envelope };

  source.buffer = getNoiseBuffer(ctx);
  filter.type = spec.filterType;
  filter.frequency.value = spec.filterFrequency;
  applyEnvelope(gain.gain, spec.start, spec.duration, spec.gain, envelope);

  source.connect(filter);
  filter.connect(gain);
  gain.connect(destination);
  source.start(spec.start);
  source.stop(spec.start + spec.duration + envelope.release + 0.04);
  source.onended = () => {
    source.disconnect();
    filter.disconnect();
    gain.disconnect();
  };
}

function createFilteredDestination(
  ctx: AudioContext,
  destination: AudioNode,
  filterType: BiquadFilterType | undefined,
  filterFrequency: number | undefined,
): AudioNode {
  if (filterType === undefined || filterFrequency === undefined) return destination;
  const filter = ctx.createBiquadFilter();
  filter.type = filterType;
  filter.frequency.value = filterFrequency;
  filter.Q.value = filterType === 'bandpass' ? 4.2 : 0.85;
  filter.connect(destination);
  return filter;
}

function applyEnvelope(param: AudioParam, start: number, duration: number, gain: number, envelope: Envelope): void {
  const attackEnd = start + envelope.attack;
  const decayEnd = attackEnd + envelope.decay;
  const holdEnd = Math.max(decayEnd + envelope.hold, start + duration);
  const releaseEnd = holdEnd + envelope.release;
  const peak = Math.max(0.0001, gain * envelope.peak);
  const sustain = Math.max(0.0001, gain * envelope.sustain);

  param.cancelScheduledValues(start);
  param.setValueAtTime(0.0001, start);
  param.exponentialRampToValueAtTime(peak, attackEnd);
  param.exponentialRampToValueAtTime(sustain, decayEnd);
  param.setValueAtTime(sustain, holdEnd);
  param.exponentialRampToValueAtTime(0.0001, releaseEnd);
}

function getNoiseBuffer(ctx: AudioContext): AudioBuffer {
  const cached = noiseBuffers.get(ctx);
  if (cached !== undefined) return cached;

  const frameCount = Math.floor(ctx.sampleRate * 1.5);
  const buffer = ctx.createBuffer(1, frameCount, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < frameCount; i++) {
    data[i] = Math.random() * 2 - 1;
  }
  noiseBuffers.set(ctx, buffer);
  return buffer;
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}
