import * as THREE from 'three';

/** Four explicit toon band colors, darkest shadow to brightest light. */
export type RampBands = readonly [string, string, string, string];

export interface WorldPalette {
  id: number;
  name: string;
  skyTop: THREE.Color;
  skyMid: THREE.Color;
  skyBot: THREE.Color;
  /** Posterization steps for the vertical sky gradient — never a smooth wash. */
  skyBandCount: number;
  fog: THREE.Color;
  accent: THREE.Color;
  ink: THREE.Color;
  platform: THREE.Color;
  platformEdge: THREE.Color;
  /** Shadowed underside/body of walkable geometry — gives platforms thickness. */
  platformDeep: THREE.Color;
  ambient: THREE.Color;
  keyLight: THREE.Color;
  fillLight: THREE.Color;
  rim: THREE.Color;
  cloud: THREE.Color;
  /** Hard shadow shelf under every cloud puff — two-tone, no gradient between. */
  cloudShadow: THREE.Color;
  /** Sun/void-eye disc color, kept separate from UI accent gold. */
  sun: THREE.Color;
  /** Diffuse ramp bands; shadow end is hue-shifted, never gray-multiplied. */
  ramp: RampBands;
}

/** Committed per-world NPR palettes — never PBR greys. */
export const WORLD_PALETTES: Record<number, WorldPalette> = {
  1: {
    id: 1,
    name: 'Kallos Frost',
    // Frost is cyan-and-cream with violet shadows, not white-and-gray. The sky
    // top and the platform underside are the frame's two dark anchors — without
    // them every surface lands in the same pale band and the world reads washed.
    skyTop: new THREE.Color('#2a63ae'),
    skyMid: new THREE.Color('#77b4e0'),
    skyBot: new THREE.Color('#eaf4fb'),
    skyBandCount: 9,
    fog: new THREE.Color('#b9d5ea'),
    accent: new THREE.Color('#ffc94a'),
    ink: new THREE.Color('#16283c'),
    platform: new THREE.Color('#d8f2ff'),
    platformEdge: new THREE.Color('#3f9fd4'),
    platformDeep: new THREE.Color('#215279'),
    ambient: new THREE.Color('#8fb4d6'),
    keyLight: new THREE.Color('#fff2d8'),
    fillLight: new THREE.Color('#5f8fc4'),
    rim: new THREE.Color('#fff0bc'),
    cloud: new THREE.Color('#ffffff'),
    cloudShadow: new THREE.Color('#8fb2d6'),
    sun: new THREE.Color('#fff3c8'),
    ramp: ['#3a5c8c', '#7099c2', '#b6d4ec', '#ffffff'],
  },
  2: {
    id: 2,
    name: 'Void Portals',
    skyTop: new THREE.Color('#1a0a28'),
    skyMid: new THREE.Color('#0e2038'),
    skyBot: new THREE.Color('#142430'),
    skyBandCount: 6,
    fog: new THREE.Color('#1a1830'),
    accent: new THREE.Color('#e040a0'),
    ink: new THREE.Color('#080610'),
    platform: new THREE.Color('#2a3048'),
    platformEdge: new THREE.Color('#3ec8c0'),
    platformDeep: new THREE.Color('#141830'),
    ambient: new THREE.Color('#281840'),
    keyLight: new THREE.Color('#50e0d0'),
    fillLight: new THREE.Color('#a03080'),
    rim: new THREE.Color('#ff60c0'),
    cloud: new THREE.Color('#472a6e'),
    cloudShadow: new THREE.Color('#1e1236'),
    sun: new THREE.Color('#7defe0'),
    ramp: ['#150e28', '#2c1f4c', '#4a3a72', '#8f7ec0'],
  },
  3: {
    id: 3,
    name: 'Forge Arcs',
    skyTop: new THREE.Color('#1a1408'),
    skyMid: new THREE.Color('#3a2010'),
    skyBot: new THREE.Color('#20180f'),
    skyBandCount: 7,
    fog: new THREE.Color('#2a1c10'),
    accent: new THREE.Color('#ffb020'),
    ink: new THREE.Color('#100c08'),
    platform: new THREE.Color('#4a4034'),
    platformEdge: new THREE.Color('#2f78e0'),
    platformDeep: new THREE.Color('#221c14'),
    ambient: new THREE.Color('#402818'),
    keyLight: new THREE.Color('#ffc040'),
    fillLight: new THREE.Color('#2860e0'),
    rim: new THREE.Color('#60c0ff'),
    cloud: new THREE.Color('#6a4326'),
    cloudShadow: new THREE.Color('#2e1c10'),
    sun: new THREE.Color('#ff8c3a'),
    ramp: ['#3a1c10', '#6e3c1c', '#b0763a', '#ffdca0'],
  },
  4: {
    id: 4,
    name: 'Dice Realm',
    // Twilight-table read: violet sky over rose bands with a gold horizon —
    // porcelain platforms with dark violet edges kill the old mustard wash.
    skyTop: new THREE.Color('#3c2560'),
    skyMid: new THREE.Color('#c2506e'),
    skyBot: new THREE.Color('#f2c05c'),
    skyBandCount: 11,
    fog: new THREE.Color('#8a5878'),
    accent: new THREE.Color('#ffd23e'),
    ink: new THREE.Color('#221030'),
    platform: new THREE.Color('#f0e6d2'),
    platformEdge: new THREE.Color('#4e3358'),
    platformDeep: new THREE.Color('#33203f'),
    ambient: new THREE.Color('#b08aa4'),
    keyLight: new THREE.Color('#ffe9b4'),
    fillLight: new THREE.Color('#7a4a84'),
    rim: new THREE.Color('#ffd88a'),
    cloud: new THREE.Color('#ffeed6'),
    cloudShadow: new THREE.Color('#c48a8e'),
    sun: new THREE.Color('#ffe08a'),
    ramp: ['#4a2c58', '#8a5a78', '#d09a9c', '#fff0d8'],
  },
};

export function getPalette(world: number): WorldPalette {
  return WORLD_PALETTES[world] ?? WORLD_PALETTES[1]!;
}
