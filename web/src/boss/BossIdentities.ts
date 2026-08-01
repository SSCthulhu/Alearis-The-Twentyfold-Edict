import type { FinalBossId, WorldId } from '../core/types';

export type BossIdentityId =
  | 'kallos'
  | 'vesperra'
  | 'crit0n'
  | 'pale_wager'
  | 'choir_broken_sevens'
  | 'umbra_bent_die'
  | 'aureline_loaded_saint'
  | 'twentyfold_sovereign';

export type BossElement = 'frost' | 'void' | 'forge' | 'fate';

export type BossMoveStyle =
  | 'ice_platform_anchor'
  | 'portal_sub_arena'
  | 'horizontal_forge_lanes'
  | 'fate_duelist'
  | 'choral_constellation'
  | 'shadow_die_shift'
  | 'saintly_orbit'
  | 'sovereign_twentyfold';

export interface BossPhaseGate {
  readonly hpRatio: number;
  readonly scheduleId: string;
  readonly castName: string;
  readonly castDurationSec: number;
  readonly addBudgetBonus: number;
}

export interface BossArenaIdentity {
  readonly profile:
    | 'vertical_ice_platforms'
    | 'portal_sub_arenas'
    | 'horizontal_forge'
    | 'final_fate_table';
  readonly preferredWidth: number;
  readonly preferredHeight: number;
  readonly hazardTags: readonly string[];
}

export interface BossIdentity {
  readonly id: BossIdentityId;
  readonly world: WorldId;
  readonly finalBossId: FinalBossId | null;
  readonly displayName: string;
  readonly title: string;
  readonly accentColor: string;
  readonly secondaryColor: string;
  readonly element: BossElement;
  readonly maxHp: number;
  readonly armorDuringAscent: number;
  readonly dpsWindowSeconds: number;
  readonly socketChargeSeconds: number;
  readonly baseAddBudget: number;
  readonly difficultyTier: number;
  readonly moveStyle: BossMoveStyle;
  readonly arena: BossArenaIdentity;
  readonly patternScheduleIds: readonly string[];
  readonly phaseGates: readonly [BossPhaseGate, BossPhaseGate];
}

export const WORLD_BOSS_IDS = {
  1: 'kallos',
  2: 'vesperra',
  3: 'crit0n',
} as const satisfies Record<1 | 2 | 3, BossIdentityId>;

export const FINAL_BOSS_IDS = {
  a: 'pale_wager',
  b: 'choir_broken_sevens',
  c: 'umbra_bent_die',
  d: 'aureline_loaded_saint',
  e: 'twentyfold_sovereign',
} as const satisfies Record<FinalBossId, BossIdentityId>;

const BOSS_IDENTITIES = {
  kallos: {
    id: 'kallos',
    world: 1,
    finalBossId: null,
    displayName: 'Kallos',
    title: 'the Frost Golem',
    accentColor: '#94d8ff',
    secondaryColor: '#d8f4ff',
    element: 'frost',
    maxHp: 18500,
    armorDuringAscent: 0.12,
    dpsWindowSeconds: 15,
    socketChargeSeconds: 10,
    baseAddBudget: 5,
    difficultyTier: 1,
    moveStyle: 'ice_platform_anchor',
    arena: {
      profile: 'vertical_ice_platforms',
      preferredWidth: 34,
      preferredHeight: 58,
      hazardTags: ['ice_platform_shift', 'falling_rime', 'frost_slow'],
    },
    patternScheduleIds: ['kallos_rime_lanes', 'kallos_glacier_cross', 'kallos_shatter_arc'],
    phaseGates: [
      {
        hpRatio: 0.7,
        scheduleId: 'kallos_floor_freeze',
        castName: 'Glacier Verdict',
        castDurationSec: 3.2,
        addBudgetBonus: 2,
      },
      {
        hpRatio: 0.35,
        scheduleId: 'kallos_whiteout_spiral',
        castName: 'Whiteout Heart',
        castDurationSec: 3.8,
        addBudgetBonus: 3,
      },
    ],
  },
  vesperra: {
    id: 'vesperra',
    world: 2,
    finalBossId: null,
    displayName: 'Vesperra',
    title: 'Gate of Hollow Stars',
    accentColor: '#b78cff',
    secondaryColor: '#4de3ff',
    element: 'void',
    maxHp: 23500,
    armorDuringAscent: 0.1,
    dpsWindowSeconds: 15,
    socketChargeSeconds: 10,
    baseAddBudget: 7,
    difficultyTier: 2,
    moveStyle: 'portal_sub_arena',
    arena: {
      profile: 'portal_sub_arenas',
      preferredWidth: 42,
      preferredHeight: 50,
      hazardTags: ['hollow_portal', 'wrong_portal_debuff', 'starless_pull'],
    },
    patternScheduleIds: ['vesperra_star_cones', 'vesperra_portal_scatter', 'vesperra_hollow_wave'],
    phaseGates: [
      {
        hpRatio: 0.7,
        scheduleId: 'vesperra_gate_shuffle',
        castName: 'False Constellation',
        castDurationSec: 3.5,
        addBudgetBonus: 3,
      },
      {
        hpRatio: 0.35,
        scheduleId: 'vesperra_event_horizon',
        castName: 'Eventide Aperture',
        castDurationSec: 4.0,
        addBudgetBonus: 4,
      },
    ],
  },
  crit0n: {
    id: 'crit0n',
    world: 3,
    finalBossId: null,
    displayName: 'CRIT-0N',
    title: 'the Forge Equation',
    accentColor: '#ffb347',
    secondaryColor: '#56f0ff',
    element: 'forge',
    maxHp: 29500,
    armorDuringAscent: 0.08,
    dpsWindowSeconds: 15,
    socketChargeSeconds: 10,
    baseAddBudget: 9,
    difficultyTier: 3,
    moveStyle: 'horizontal_forge_lanes',
    arena: {
      profile: 'horizontal_forge',
      preferredWidth: 62,
      preferredHeight: 28,
      hazardTags: ['forge_lanes', 'electric_coils', 'slag_bursts'],
    },
    patternScheduleIds: ['crit0n_laser_cross', 'crit0n_sine_voltage', 'crit0n_slag_spiral'],
    phaseGates: [
      {
        hpRatio: 0.7,
        scheduleId: 'crit0n_equation_shift',
        castName: 'Recalculate Arena',
        castDurationSec: 3.0,
        addBudgetBonus: 4,
      },
      {
        hpRatio: 0.35,
        scheduleId: 'crit0n_overclock',
        castName: 'Overclocked Proof',
        castDurationSec: 4.2,
        addBudgetBonus: 5,
      },
    ],
  },
  pale_wager: {
    id: 'pale_wager',
    world: 4,
    finalBossId: 'a',
    displayName: 'The Pale Wager',
    title: 'Ante of the Empty Hand',
    accentColor: '#f5ead7',
    secondaryColor: '#9c86ff',
    element: 'fate',
    maxHp: 33000,
    armorDuringAscent: 0.08,
    dpsWindowSeconds: 15,
    socketChargeSeconds: 10,
    baseAddBudget: 10,
    difficultyTier: 4,
    moveStyle: 'fate_duelist',
    arena: {
      profile: 'final_fate_table',
      preferredWidth: 46,
      preferredHeight: 46,
      hazardTags: ['pale_coin_toss', 'empty_hand_curse', 'ante_lanes'],
    },
    patternScheduleIds: ['pale_wager_coin_lines', 'pale_wager_cone_bluff', 'pale_wager_arc_call'],
    phaseGates: [
      {
        hpRatio: 0.7,
        scheduleId: 'pale_wager_raise',
        castName: 'Raise the Ante',
        castDurationSec: 3.2,
        addBudgetBonus: 4,
      },
      {
        hpRatio: 0.35,
        scheduleId: 'pale_wager_all_in',
        castName: 'All In Silence',
        castDurationSec: 4.0,
        addBudgetBonus: 5,
      },
    ],
  },
  choir_broken_sevens: {
    id: 'choir_broken_sevens',
    world: 4,
    finalBossId: 'b',
    displayName: 'Choir of Broken Sevens',
    title: 'Seven Voices, Six Graves',
    accentColor: '#ff7ac8',
    secondaryColor: '#fff06a',
    element: 'fate',
    maxHp: 37000,
    armorDuringAscent: 0.07,
    dpsWindowSeconds: 15,
    socketChargeSeconds: 10,
    baseAddBudget: 12,
    difficultyTier: 5,
    moveStyle: 'choral_constellation',
    arena: {
      profile: 'final_fate_table',
      preferredWidth: 50,
      preferredHeight: 48,
      hazardTags: ['chorus_orbits', 'seventh_note_burst', 'hymn_debuff'],
    },
    patternScheduleIds: ['choir_seven_radials', 'choir_broken_wave', 'choir_harmony_spiral'],
    phaseGates: [
      {
        hpRatio: 0.7,
        scheduleId: 'choir_sixth_grave',
        castName: 'Sixth Grave Hymn',
        castDurationSec: 3.4,
        addBudgetBonus: 5,
      },
      {
        hpRatio: 0.35,
        scheduleId: 'choir_missing_seventh',
        castName: 'The Missing Seventh',
        castDurationSec: 4.3,
        addBudgetBonus: 6,
      },
    ],
  },
  umbra_bent_die: {
    id: 'umbra_bent_die',
    world: 4,
    finalBossId: 'c',
    displayName: 'Umbra of the Bent Die',
    title: 'Shadow Under Every Roll',
    accentColor: '#6f5cff',
    secondaryColor: '#1ee6a8',
    element: 'fate',
    maxHp: 41500,
    armorDuringAscent: 0.06,
    dpsWindowSeconds: 15,
    socketChargeSeconds: 10,
    baseAddBudget: 13,
    difficultyTier: 6,
    moveStyle: 'shadow_die_shift',
    arena: {
      profile: 'final_fate_table',
      preferredWidth: 52,
      preferredHeight: 52,
      hazardTags: ['bent_die_clone', 'shadow_safe_spot', 'skewed_roll'],
    },
    patternScheduleIds: ['umbra_shadow_cross', 'umbra_bent_scatter', 'umbra_sine_eclipse'],
    phaseGates: [
      {
        hpRatio: 0.7,
        scheduleId: 'umbra_loaded_shadow',
        castName: 'Loaded Shadow',
        castDurationSec: 3.6,
        addBudgetBonus: 5,
      },
      {
        hpRatio: 0.35,
        scheduleId: 'umbra_die_break',
        castName: 'Break the Die',
        castDurationSec: 4.5,
        addBudgetBonus: 7,
      },
    ],
  },
  aureline_loaded_saint: {
    id: 'aureline_loaded_saint',
    world: 4,
    finalBossId: 'd',
    displayName: 'Aureline the Loaded Saint',
    title: 'Halo of Weighted Odds',
    accentColor: '#ffd36e',
    secondaryColor: '#ff6f91',
    element: 'fate',
    maxHp: 46500,
    armorDuringAscent: 0.05,
    dpsWindowSeconds: 15,
    socketChargeSeconds: 10,
    baseAddBudget: 15,
    difficultyTier: 7,
    moveStyle: 'saintly_orbit',
    arena: {
      profile: 'final_fate_table',
      preferredWidth: 54,
      preferredHeight: 54,
      hazardTags: ['weighted_halo', 'saint_orbitals', 'absolution_beams'],
    },
    patternScheduleIds: ['aureline_halo_arc', 'aureline_absolution_lines', 'aureline_weighted_spiral'],
    phaseGates: [
      {
        hpRatio: 0.7,
        scheduleId: 'aureline_weighted_grace',
        castName: 'Weighted Grace',
        castDurationSec: 3.8,
        addBudgetBonus: 6,
      },
      {
        hpRatio: 0.35,
        scheduleId: 'aureline_loaded_miracle',
        castName: 'Loaded Miracle',
        castDurationSec: 4.7,
        addBudgetBonus: 8,
      },
    ],
  },
  twentyfold_sovereign: {
    id: 'twentyfold_sovereign',
    world: 4,
    finalBossId: 'e',
    displayName: 'Twentyfold Sovereign',
    title: 'The Edict Made Flesh',
    accentColor: '#f7d76b',
    secondaryColor: '#e04bff',
    element: 'fate',
    maxHp: 54000,
    armorDuringAscent: 0.04,
    dpsWindowSeconds: 15,
    socketChargeSeconds: 10,
    baseAddBudget: 18,
    difficultyTier: 8,
    moveStyle: 'sovereign_twentyfold',
    arena: {
      profile: 'final_fate_table',
      preferredWidth: 60,
      preferredHeight: 60,
      hazardTags: ['edict_twenty', 'sovereign_decree', 'dice_range_judgment'],
    },
    patternScheduleIds: ['sovereign_twenty_spokes', 'sovereign_decree_waves', 'sovereign_final_edict'],
    phaseGates: [
      {
        hpRatio: 0.7,
        scheduleId: 'sovereign_first_edict',
        castName: 'First Edict: Kneel',
        castDurationSec: 4.0,
        addBudgetBonus: 8,
      },
      {
        hpRatio: 0.35,
        scheduleId: 'sovereign_twentieth_edict',
        castName: 'Twentieth Edict: Endure',
        castDurationSec: 5.0,
        addBudgetBonus: 10,
      },
    ],
  },
} as const satisfies Record<BossIdentityId, BossIdentity>;

export function getBossIdentity(id: BossIdentityId): BossIdentity {
  return BOSS_IDENTITIES[id];
}

export function getWorldBossIdentity(world: 1 | 2 | 3): BossIdentity {
  return BOSS_IDENTITIES[WORLD_BOSS_IDS[world]];
}

export function getFinalBossIdentity(finalBossId: FinalBossId): BossIdentity {
  return BOSS_IDENTITIES[FINAL_BOSS_IDS[finalBossId]];
}

export function selectFinalBossIdFromDiceRoll(roll: number): FinalBossId {
  if (roll <= 4) return 'a';
  if (roll <= 8) return 'b';
  if (roll <= 12) return 'c';
  if (roll <= 16) return 'd';
  return 'e';
}

export function selectFinalBossIdentityFromDiceRoll(roll: number): BossIdentity {
  return getFinalBossIdentity(selectFinalBossIdFromDiceRoll(roll));
}

export function listBossIdentities(): BossIdentity[] {
  return Object.values(BOSS_IDENTITIES);
}

export function getBossNameList(): string[] {
  return listBossIdentities().map((boss) => `${boss.displayName}, ${boss.title}`);
}
