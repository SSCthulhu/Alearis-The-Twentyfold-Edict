/** Shared domain types for Alearis: The Twentyfold Edict */

export type ClassId = 'knight' | 'rogue' | 'mage';

export type WorldId = 1 | 2 | 3 | 4;

export type GamePhase =
  | 'boot'
  | 'main_menu'
  | 'character_select'
  | 'tutorial'
  | 'floor_intro'
  | 'combat'
  | 'chest'
  | 'modifier_choice'
  | 'boss_intro'
  | 'boss_fight'
  | 'victory_roll'
  | 'relic_choice'
  | 'world_transition'
  | 'final_boss_roll'
  | 'victory'
  | 'death'
  | 'pause';

export type DiceDelta = -2 | -1 | 0 | 1 | 2;

export type RelicRarity = 'COMMON' | 'RARE' | 'EPIC' | 'LEGENDARY';
export type RelicBand = 'SURVIVAL' | 'CORE' | 'GREED_DAMAGE';

export type RngDomain =
  | 'modifier_options'
  | 'victory_reward'
  | 'relic_choices'
  | 'final_boss'
  | 'encounter'
  | 'boss_projectiles'
  | 'dice_meter'
  | 'vfx'
  | 'audio'
  | 'layout';

export type FinalBossId = 'a' | 'b' | 'c' | 'd' | 'e';

export interface Vec2 {
  x: number;
  y: number;
}

export interface AABB {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface DamageInfo {
  amount: number;
  source: 'player' | 'enemy' | 'boss' | 'hazard' | 'system';
  crit: boolean;
  elemental?: 'frost' | 'void' | 'forge' | 'fate' | 'none';
  knockback?: number;
}
