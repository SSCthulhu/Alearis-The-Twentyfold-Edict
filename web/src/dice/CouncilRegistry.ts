export type CouncilPolarity = 'council' | 'divine' | 'miracle' | 'catastrophe';

export type CouncilEffectId =
  | 'catastrophe_pressure'
  | 'edict_projectile_bloom'
  | 'divine_mending_rain'
  | 'council_gravity_trial'
  | 'divine_frost_stasis'
  | 'council_blood_tithe'
  | 'divine_forge_overheat'
  | 'council_void_lanterns'
  | 'divine_fate_echo'
  | 'council_enemy_ward'
  | 'divine_kallos_barrier'
  | 'council_silence'
  | 'divine_smite_glyphs'
  | 'council_chain_floor'
  | 'divine_clarity'
  | 'council_mirror_spawns'
  | 'divine_bulwark'
  | 'council_final_exam'
  | 'divine_ascendant_haste'
  | 'dice_god_intervention';

export interface CouncilEvent {
  roll: number;
  id: string;
  name: string;
  polarity: CouncilPolarity;
  duration: number;
  description: string;
  effectId: CouncilEffectId;
  params: Record<string, number>;
}

export const COUNCIL_EVENTS: readonly CouncilEvent[] = [
  {
    roll: 1,
    id: 'total_council_control',
    name: 'Total Council Control',
    polarity: 'catastrophe',
    duration: 12,
    description:
      'The Council floods the arena with temporary pressure hazards, but the edict cannot directly end the run.',
    effectId: 'catastrophe_pressure',
    params: { hazardPulses: 5, warningSeconds: 0.9, safeLaneCount: 1 },
  },
  {
    roll: 2,
    id: 'vathros_the_iron_clerk',
    name: 'Vathros, the Iron Clerk',
    polarity: 'council',
    duration: 14,
    description: 'Stamped warrants split hostile shots into readable but denser patterns.',
    effectId: 'edict_projectile_bloom',
    params: { projectileSplitAdd: 1, speedMult: 0.82, warningSeconds: 0.6 },
  },
  {
    roll: 3,
    id: 'elyra_of_the_blue_basin',
    name: 'Elyra of the Blue Basin',
    polarity: 'divine',
    duration: 10,
    description: 'Blue rain falls in brief pockets that restore health when crossed.',
    effectId: 'divine_mending_rain',
    params: { healPerPool: 6, poolCount: 3, poolRadius: 2.4 },
  },
  {
    roll: 4,
    id: 'mordane_the_weight_scribe',
    name: 'Mordane, the Weight-Scribe',
    polarity: 'council',
    duration: 12,
    description: 'Gravity surges in pulses, demanding grounded timing without dealing lethal damage.',
    effectId: 'council_gravity_trial',
    params: { gravityMult: 1.35, pulseSeconds: 2, warningSeconds: 0.75 },
  },
  {
    roll: 5,
    id: 'saint_nivara_frost_lantern',
    name: 'Saint Nivara, Frost-Lantern',
    polarity: 'divine',
    duration: 9,
    description: 'A frost lantern periodically slows enemies caught in its halo.',
    effectId: 'divine_frost_stasis',
    params: { enemySlowMult: 0.65, pulseCount: 3, radius: 3 },
  },
  {
    roll: 6,
    id: 'balor_of_the_red_ledger',
    name: 'Balor of the Red Ledger',
    polarity: 'council',
    duration: 14,
    description: 'A blood tithe marks the floor; standing still too long draws harmless pressure sigils.',
    effectId: 'council_blood_tithe',
    params: { sigilCount: 4, armSeconds: 1.1, movementGraceSeconds: 1.5 },
  },
  {
    roll: 7,
    id: 'aurex_the_forge_choir',
    name: 'Aurex, the Forge Choir',
    polarity: 'divine',
    duration: 10,
    description: 'Forge choirs overheat enemy armor, briefly increasing damage they take.',
    effectId: 'divine_forge_overheat',
    params: { enemyDamageTakenMult: 1.18, pulseCount: 2, radius: 3.5 },
  },
  {
    roll: 8,
    id: 'selkyr_the_void_bailiff',
    name: 'Selkyr, the Void Bailiff',
    polarity: 'council',
    duration: 13,
    description: 'Void lanterns narrow sightlines and telegraph safe paths in sharp gold.',
    effectId: 'council_void_lanterns',
    params: { lanternCount: 5, visibilityMult: 0.72, safeGlowSeconds: 1 },
  },
  {
    roll: 9,
    id: 'irenna_of_the_second_chance',
    name: 'Irenna of the Second Chance',
    polarity: 'divine',
    duration: 11,
    description: 'The next clean dodge echoes, briefly granting a second speed burst.',
    effectId: 'divine_fate_echo',
    params: { echoSpeedMult: 1.18, echoSeconds: 1.6, maxEchoes: 2 },
  },
  {
    roll: 10,
    id: 'kharon_the_shield_notary',
    name: 'Kharon, the Shield Notary',
    polarity: 'council',
    duration: 12,
    description: 'A rotating enemy ward appears, asking you to change angles of attack.',
    effectId: 'council_enemy_ward',
    params: { wardArcDegrees: 80, rotationSeconds: 3, damageBlockedMult: 0.45 },
  },
  {
    roll: 11,
    id: 'kallos_the_open_palm',
    name: 'Kallos, the Open Palm',
    polarity: 'divine',
    duration: 10,
    description: 'A gold barrier absorbs one mistake and then shatters into harmless sparks.',
    effectId: 'divine_kallos_barrier',
    params: { hitBuffer: 1, barrierSeconds: 10, shatterKnockback: 0.5 },
  },
  {
    roll: 12,
    id: 'orum_the_quiet_judge',
    name: 'Orum, the Quiet Judge',
    polarity: 'council',
    duration: 8,
    description: 'The arena hushes; ability cadence slows briefly while enemy tells brighten.',
    effectId: 'council_silence',
    params: { cooldownRecoveryMult: 0.78, tellBrightnessMult: 1.4, durationFloor: 8 },
  },
  {
    roll: 13,
    id: 'thessa_of_smite_glyphs',
    name: 'Thessa of Smite Glyphs',
    polarity: 'divine',
    duration: 9,
    description: 'Gold glyphs mark enemies and burst for bonus pressure when struck.',
    effectId: 'divine_smite_glyphs',
    params: { glyphCount: 3, bonusDamageMult: 1.25, markSeconds: 4 },
  },
  {
    roll: 14,
    id: 'malrec_the_chain_architect',
    name: 'Malrec, the Chain Architect',
    polarity: 'council',
    duration: 12,
    description: 'Spectral chains sketch temporary movement puzzles across platforms.',
    effectId: 'council_chain_floor',
    params: { chainCount: 4, slowMult: 0.7, telegraphSeconds: 0.8 },
  },
  {
    roll: 15,
    id: 'sova_of_clear_sight',
    name: 'Sova of Clear Sight',
    polarity: 'divine',
    duration: 12,
    description: 'Enemy intent lines and projectile arcs become easier to read.',
    effectId: 'divine_clarity',
    params: { telegraphSecondsAdd: 0.35, projectileSpeedMult: 0.82, projectileAlphaMult: 1.35, critWindowAdd: 0.05 },
  },
  {
    roll: 16,
    id: 'nyxara_the_mirror_prosecutor',
    name: 'Nyxara, the Mirror Prosecutor',
    polarity: 'council',
    duration: 10,
    description: 'Mirror shades appear with fragile bodies and obvious tells.',
    effectId: 'council_mirror_spawns',
    params: { shadeCount: 2, shadeHpMult: 0.35, rewardMeterOnDefeat: 3 },
  },
  {
    roll: 17,
    id: 'brannoc_of_the_last_wall',
    name: 'Brannoc of the Last Wall',
    polarity: 'divine',
    duration: 10,
    description: 'A last-wall blessing reduces incoming damage during the event.',
    effectId: 'divine_bulwark',
    params: { damageTakenMult: 0.75, knockbackResistMult: 1.25, durationFloor: 10 },
  },
  {
    roll: 18,
    id: 'cassian_the_examiner',
    name: 'Cassian, the Examiner',
    polarity: 'council',
    duration: 15,
    description: 'The Council calls a final exam: more hazards, more warning, no lethal verdict.',
    effectId: 'council_final_exam',
    params: { hazardFrequencyMult: 1.25, warningSecondsAdd: 0.35, meterRefundOnSurvive: 10 },
  },
  {
    roll: 19,
    id: 'veloria_the_ascending_sun',
    name: 'Veloria, the Ascending Sun',
    polarity: 'divine',
    duration: 12,
    description: 'The ascending sun grants speed and cooldown recovery for a short divine tempo break.',
    effectId: 'divine_ascendant_haste',
    params: { moveSpeedMult: 1.16, cooldownRecoveryMult: 1.2, glowRadius: 3 },
  },
  {
    roll: 20,
    id: 'dice_god_intervention',
    name: 'Dice God Intervention',
    polarity: 'miracle',
    duration: 14,
    description: 'The Dice God bends the arena toward mercy: healing, haste, and slowed enemy fire.',
    effectId: 'dice_god_intervention',
    params: { heal: 20, moveSpeedMult: 1.18, enemyProjectileSpeedMult: 0.72 },
  },
];

export const COUNCIL_EVENT_BY_ROLL: ReadonlyMap<number, CouncilEvent> = new Map(
  COUNCIL_EVENTS.map((event) => [event.roll, event]),
);

export function getCouncilEvent(roll: number): CouncilEvent {
  const event = COUNCIL_EVENT_BY_ROLL.get(roll);
  if (event === undefined) {
    throw new RangeError(`No Council event registered for roll ${roll}.`);
  }
  return event;
}

export function lookupCouncilEvent(roll: number): CouncilEvent | null {
  return COUNCIL_EVENT_BY_ROLL.get(roll) ?? null;
}
