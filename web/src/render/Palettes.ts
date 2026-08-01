import * as THREE from 'three';

export interface WorldPalette {
  id: number;
  name: string;
  skyTop: THREE.Color;
  skyMid: THREE.Color;
  skyBot: THREE.Color;
  fog: THREE.Color;
  accent: THREE.Color;
  ink: THREE.Color;
  platform: THREE.Color;
  platformEdge: THREE.Color;
  ambient: THREE.Color;
  keyLight: THREE.Color;
  fillLight: THREE.Color;
  rim: THREE.Color;
  cloud: THREE.Color;
}

/** Committed per-world NPR palettes — never PBR greys. */
export const WORLD_PALETTES: Record<number, WorldPalette> = {
  1: {
    id: 1,
    name: 'Kallos Frost',
    skyTop: new THREE.Color('#b8d4f0'),
    skyMid: new THREE.Color('#7eb0d4'),
    skyBot: new THREE.Color('#e8f0f8'),
    fog: new THREE.Color('#c5d8ea'),
    accent: new THREE.Color('#e8c872'),
    ink: new THREE.Color('#1a2430'),
    platform: new THREE.Color('#d0e4f2'),
    platformEdge: new THREE.Color('#8ab4d0'),
    ambient: new THREE.Color('#a0c0d8'),
    keyLight: new THREE.Color('#fff2d8'),
    fillLight: new THREE.Color('#6a9cc0'),
    rim: new THREE.Color('#ffe9a8'),
    cloud: new THREE.Color('#f4f8fc'),
  },
  2: {
    id: 2,
    name: 'Void Portals',
    skyTop: new THREE.Color('#1a0a28'),
    skyMid: new THREE.Color('#0e2038'),
    skyBot: new THREE.Color('#142430'),
    fog: new THREE.Color('#1a1830'),
    accent: new THREE.Color('#e040a0'),
    ink: new THREE.Color('#080610'),
    platform: new THREE.Color('#2a3048'),
    platformEdge: new THREE.Color('#3ec8c0'),
    ambient: new THREE.Color('#281840'),
    keyLight: new THREE.Color('#50e0d0'),
    fillLight: new THREE.Color('#a03080'),
    rim: new THREE.Color('#ff60c0'),
    cloud: new THREE.Color('#402060'),
  },
  3: {
    id: 3,
    name: 'Forge Arcs',
    skyTop: new THREE.Color('#1a1408'),
    skyMid: new THREE.Color('#3a2010'),
    skyBot: new THREE.Color('#201810'),
    fog: new THREE.Color('#2a1c10'),
    accent: new THREE.Color('#ffb020'),
    ink: new THREE.Color('#100c08'),
    platform: new THREE.Color('#3a3428'),
    platformEdge: new THREE.Color('#2060d0'),
    ambient: new THREE.Color('#402818'),
    keyLight: new THREE.Color('#ffc040'),
    fillLight: new THREE.Color('#2860e0'),
    rim: new THREE.Color('#60c0ff'),
    cloud: new THREE.Color('#504030'),
  },
  4: {
    id: 4,
    name: 'Dice Realm',
    skyTop: new THREE.Color('#f5f0e0'),
    skyMid: new THREE.Color('#d8c8a0'),
    skyBot: new THREE.Color('#2a2018'),
    fog: new THREE.Color('#c8b890'),
    accent: new THREE.Color('#f0d060'),
    ink: new THREE.Color('#1a1008'),
    platform: new THREE.Color('#e8dcc0'),
    platformEdge: new THREE.Color('#8a7040'),
    ambient: new THREE.Color('#d0c0a0'),
    keyLight: new THREE.Color('#fff8e0'),
    fillLight: new THREE.Color('#604830'),
    rim: new THREE.Color('#ffe080'),
    cloud: new THREE.Color('#fff8f0'),
  },
};

export function getPalette(world: number): WorldPalette {
  return WORLD_PALETTES[world] ?? WORLD_PALETTES[1]!;
}
