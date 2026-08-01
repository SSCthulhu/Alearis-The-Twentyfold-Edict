import { AudioEngine } from './AudioEngine';

export type WorldMusicId = 1 | 2 | 3 | 4 | 'w1' | 'w2' | 'w3' | 'final';

export interface MusicBedOptions {
  fadeInSeconds?: number;
  bossDpsActive?: boolean;
}

interface ActiveMusicBed {
  output: GainNode;
  bossGain: GainNode;
  intensityGain: GainNode;
  timers: number[];
  sources: AudioScheduledSourceNode[];
  stop: (fadeSeconds?: number) => void;
}

interface MusicToneSpec {
  destination: AudioNode;
  frequency: number;
  start: number;
  duration: number;
  type: OscillatorType;
  gain: number;
  filterFrequency?: number;
  detune?: number;
}

const W1_BELLS = [261.63, 392, 523.25, 783.99, 587.33, 392];
const W2_PULSES = [98, 103.83, 146.83, 138.59, 110, 103.83];
const W3_OSTINATO = [110, 146.83, 164.81, 146.83, 196, 164.81, 146.83, 130.81];
const FINAL_ARP = [196, 261.63, 311.13, 392, 466.16, 622.25, 783.99, 932.33];

export class MusicBeds {
  private readonly engine: AudioEngine;
  private current: ActiveMusicBed | null = null;
  private intensity = 0;

  constructor(engine: AudioEngine) {
    this.engine = engine;
  }

  startWorld(world: WorldMusicId, options: MusicBedOptions = {}): void {
    this.stop(0.45);
    const normalized = normalizeWorld(world);
    const ctx = this.engine.context;
    const output = ctx.createGain();
    const intensityGain = ctx.createGain();
    const bossGain = ctx.createGain();
    const now = ctx.currentTime;

    output.gain.setValueAtTime(0.0001, now);
    output.gain.exponentialRampToValueAtTime(0.72, now + (options.fadeInSeconds ?? 1.2));
    intensityGain.gain.value = 0.16 + this.intensity * 0.34;
    bossGain.gain.value = options.bossDpsActive === true ? 0.74 : 0.0001;
    intensityGain.connect(output);
    bossGain.connect(output);
    output.connect(this.engine.musicBus);

    const bed: ActiveMusicBed = {
      output,
      intensityGain,
      bossGain,
      timers: [],
      sources: [],
      stop: (fadeSeconds = 0.8) => {
        const stopNow = ctx.currentTime;
        output.gain.cancelScheduledValues(stopNow);
        output.gain.setTargetAtTime(0.0001, stopNow, Math.max(0.02, fadeSeconds * 0.22));
        bed.timers.forEach((timer) => window.clearInterval(timer));
        bed.sources.forEach((source) => stopSource(source, stopNow + fadeSeconds + 0.08));
        window.setTimeout(() => output.disconnect(), Math.max(120, (fadeSeconds + 0.15) * 1000));
      },
    };

    this.current = bed;
    if (normalized === 1) this.createFrostBed(bed);
    else if (normalized === 2) this.createVoidBed(bed);
    else if (normalized === 3) this.createForgeBed(bed);
    else this.createFinalBed(bed);
  }

  stop(fadeSeconds = 0.8): void {
    if (this.current === null) return;
    this.current.stop(fadeSeconds);
    this.current = null;
  }

  setIntensity(value: number): void {
    this.intensity = clamp01(value);
    if (this.current === null) return;
    const now = this.engine.context.currentTime;
    this.current.intensityGain.gain.setTargetAtTime(0.16 + this.intensity * 0.34, now, 0.18);
  }

  setBossDpsActive(active: boolean): void {
    if (this.current === null) return;
    const now = this.engine.context.currentTime;
    this.current.bossGain.gain.setTargetAtTime(active ? 0.78 : 0.0001, now, active ? 0.08 : 0.22);
  }

  private createFrostBed(bed: ActiveMusicBed): void {
    const ctx = this.engine.context;
    const drone = this.createDrone([130.81, 196, 261.63], 'triangle', 0.09, 1100);
    drone.connect(bed.output);
    bed.sources.push(...drone.sources);

    let step = 0;
    bed.timers.push(window.setInterval(() => {
      const now = ctx.currentTime;
      const frequency = W1_BELLS[step % W1_BELLS.length]!;
      scheduleMusicTone(ctx, {
        destination: bed.intensityGain,
        frequency,
        start: now + 0.02,
        duration: 2.8,
        type: 'sine',
        gain: 0.075,
        filterFrequency: 3600,
        detune: step % 2 === 0 ? 3 : -5,
      });
      if (step % 4 === 0) {
        scheduleMusicTone(ctx, {
          destination: bed.output,
          frequency: frequency * 0.5,
          start: now,
          duration: 3.4,
          type: 'triangle',
          gain: 0.055,
          filterFrequency: 900,
        });
      }
      step += 1;
    }, 760));

    this.addBossArpLayer(bed, [523.25, 587.33, 783.99, 880], 240, 'frost');
  }

  private createVoidBed(bed: ActiveMusicBed): void {
    const ctx = this.engine.context;
    const drone = this.createDrone([49, 73.42, 103.83], 'sawtooth', 0.055, 620);
    drone.filter.Q.value = 7.5;
    drone.connect(bed.output);
    bed.sources.push(...drone.sources);

    let step = 0;
    bed.timers.push(window.setInterval(() => {
      const now = ctx.currentTime;
      const frequency = W2_PULSES[step % W2_PULSES.length]!;
      schedulePulse(ctx, bed.intensityGain, frequency, now, 0.42, 0.13);
      if (step % 3 === 0) schedulePulse(ctx, bed.output, frequency * 2.01, now + 0.12, 0.28, 0.05);
      step += 1;
    }, 520));

    this.addBossArpLayer(bed, [196, 207.65, 277.18, 311.13], 180, 'void');
  }

  private createForgeBed(bed: ActiveMusicBed): void {
    const ctx = this.engine.context;
    const drone = this.createDrone([55, 110, 220], 'square', 0.045, 740);
    drone.connect(bed.output);
    bed.sources.push(...drone.sources);

    let step = 0;
    bed.timers.push(window.setInterval(() => {
      const now = ctx.currentTime;
      const frequency = W3_OSTINATO[step % W3_OSTINATO.length]!;
      scheduleMusicTone(ctx, {
        destination: bed.intensityGain,
        frequency,
        start: now,
        duration: 0.22,
        type: 'sawtooth',
        gain: step % 4 === 0 ? 0.13 : 0.085,
        filterFrequency: 1200,
      });
      if (step % 2 === 0) schedulePercussiveNoise(ctx, bed.output, now, 0.07, 0.09, 1180);
      step += 1;
    }, 210));

    this.addBossArpLayer(bed, [220, 246.94, 293.66, 329.63, 392], 150, 'forge');
  }

  private createFinalBed(bed: ActiveMusicBed): void {
    const ctx = this.engine.context;
    const drone = this.createDrone([36.71, 55, 82.41, 123.47], 'sawtooth', 0.05, 520);
    drone.filter.frequency.setValueAtTime(420, ctx.currentTime);
    drone.connect(bed.output);
    bed.sources.push(...drone.sources);

    let step = 0;
    bed.timers.push(window.setInterval(() => {
      const now = ctx.currentTime;
      const frequency = FINAL_ARP[step % FINAL_ARP.length]!;
      scheduleMusicTone(ctx, {
        destination: step % 3 === 0 ? bed.output : bed.intensityGain,
        frequency,
        start: now + 0.04,
        duration: 1.6,
        type: step % 2 === 0 ? 'triangle' : 'sine',
        gain: 0.07,
        filterFrequency: 2500,
        detune: (step % 5) * 4 - 8,
      });
      step += 1;
    }, 390));

    this.addBossArpLayer(bed, [392, 466.16, 622.25, 783.99, 932.33, 1244.51], 130, 'cosmic');
  }

  private createDrone(frequencies: readonly number[], type: OscillatorType, gainValue: number, filterFrequency: number): {
    connect: (destination: AudioNode) => void;
    filter: BiquadFilterNode;
    sources: AudioScheduledSourceNode[];
  } {
    const ctx = this.engine.context;
    const now = ctx.currentTime;
    const gain = ctx.createGain();
    const filter = ctx.createBiquadFilter();
    const lfo = ctx.createOscillator();
    const lfoGain = ctx.createGain();
    const sources: AudioScheduledSourceNode[] = [];

    gain.gain.value = gainValue;
    filter.type = 'lowpass';
    filter.frequency.value = filterFrequency;
    filter.Q.value = 1.2;
    lfo.type = 'sine';
    lfo.frequency.value = 0.055;
    lfoGain.gain.value = filterFrequency * 0.18;
    lfo.connect(lfoGain);
    lfoGain.connect(filter.frequency);
    lfo.start(now);
    sources.push(lfo);

    frequencies.forEach((frequency, index) => {
      const osc = ctx.createOscillator();
      osc.type = type;
      osc.frequency.value = frequency;
      osc.detune.value = index % 2 === 0 ? -8 : 11;
      osc.connect(gain);
      osc.start(now);
      sources.push(osc);
    });

    gain.connect(filter);
    return {
      filter,
      sources,
      connect: (destination: AudioNode) => filter.connect(destination),
    };
  }

  private addBossArpLayer(bed: ActiveMusicBed, notes: readonly number[], intervalMs: number, color: 'frost' | 'void' | 'forge' | 'cosmic'): void {
    const ctx = this.engine.context;
    let step = 0;
    bed.timers.push(window.setInterval(() => {
      const now = ctx.currentTime;
      const frequency = notes[step % notes.length]!;
      scheduleMusicTone(ctx, {
        destination: bed.bossGain,
        frequency,
        start: now,
        duration: intervalMs / 1000 + 0.08,
        type: color === 'forge' ? 'square' : 'triangle',
        gain: color === 'void' ? 0.09 : 0.075,
        filterFrequency: color === 'cosmic' ? 4200 : 2400,
      });
      if (step % 4 === 0) {
        schedulePercussiveNoise(ctx, bed.bossGain, now, 0.08, color === 'frost' ? 0.05 : 0.1, color === 'forge' ? 780 : 2600);
      }
      step += 1;
    }, intervalMs));
  }
}

function normalizeWorld(world: WorldMusicId): 1 | 2 | 3 | 4 {
  if (world === 'w1') return 1;
  if (world === 'w2') return 2;
  if (world === 'w3') return 3;
  if (world === 'final') return 4;
  return world;
}

function scheduleMusicTone(ctx: AudioContext, spec: MusicToneSpec): void {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  const filter = ctx.createBiquadFilter();
  const start = spec.start;
  const end = start + spec.duration;

  osc.type = spec.type;
  osc.frequency.setValueAtTime(spec.frequency, start);
  if (spec.detune !== undefined) osc.detune.value = spec.detune;
  filter.type = 'lowpass';
  filter.frequency.value = spec.filterFrequency ?? 1800;
  filter.Q.value = 0.9;
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(Math.max(0.0001, spec.gain), start + 0.025);
  gain.gain.setTargetAtTime(0.0001, Math.max(start + 0.03, end - 0.14), 0.05);

  osc.connect(filter);
  filter.connect(gain);
  gain.connect(spec.destination);
  osc.start(start);
  osc.stop(end + 0.08);
  osc.onended = () => {
    osc.disconnect();
    filter.disconnect();
    gain.disconnect();
  };
}

function schedulePulse(ctx: AudioContext, destination: AudioNode, frequency: number, start: number, duration: number, gainValue: number): void {
  scheduleMusicTone(ctx, {
    destination,
    frequency,
    start,
    duration,
    type: 'sawtooth',
    gain: gainValue,
    filterFrequency: 680,
    detune: -4,
  });
  scheduleMusicTone(ctx, {
    destination,
    frequency: frequency * 1.5,
    start: start + 0.035,
    duration: duration * 0.72,
    type: 'triangle',
    gain: gainValue * 0.42,
    filterFrequency: 1100,
    detune: 7,
  });
}

function schedulePercussiveNoise(ctx: AudioContext, destination: AudioNode, start: number, duration: number, gainValue: number, filterFrequency: number): void {
  const source = ctx.createBufferSource();
  const gain = ctx.createGain();
  const filter = ctx.createBiquadFilter();
  source.buffer = makeNoiseBuffer(ctx, 0.4);
  filter.type = 'bandpass';
  filter.frequency.value = filterFrequency;
  filter.Q.value = 5;
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(gainValue, start + 0.004);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  source.connect(filter);
  filter.connect(gain);
  gain.connect(destination);
  source.start(start);
  source.stop(start + duration + 0.02);
  source.onended = () => {
    source.disconnect();
    filter.disconnect();
    gain.disconnect();
  };
}

function makeNoiseBuffer(ctx: AudioContext, seconds: number): AudioBuffer {
  const frameCount = Math.max(1, Math.floor(ctx.sampleRate * seconds));
  const buffer = ctx.createBuffer(1, frameCount, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < frameCount; i++) {
    const shaped = Math.random() * 2 - 1;
    data[i] = shaped * (1 - i / frameCount);
  }
  return buffer;
}

function stopSource(source: AudioScheduledSourceNode, when: number): void {
  try {
    source.stop(when);
  } catch {
    // A source may already have ended; stopping is best-effort during bed fades.
  }
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}
