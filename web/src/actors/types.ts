export type FigureAnimName =
  | 'idle'
  | 'walk'
  | 'run'
  | 'jump'
  | 'fall'
  | 'attack'
  | 'cast'
  | 'hurt'
  | 'death';

export interface FigureAnimState {
  name: FigureAnimName;
  speed?: number;
  attackT?: number;
  deathT?: number;
  intensity?: number;
}
