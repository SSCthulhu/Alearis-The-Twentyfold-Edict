import type { DiceDelta } from '../core/types';
import type { RunState } from '../core/RunState';
import { rngShuffle } from '../core/SeededRng';
import { MODIFIER_DATABASE, type ModifierDef } from './ModifierDatabase';

const OFFER_SIZE = 5;
const NON_HEAL_DELTAS: readonly DiceDelta[] = [-2, -1, 1, 2];

export function offerModifiers(run: RunState): ModifierDef[] {
  const rng = run.rng('modifier_options', run.worldModifiers.length);
  const available = MODIFIER_DATABASE.filter((modifier) => canOfferModifier(run, modifier));
  const selected: ModifierDef[] = [];
  const selectedIds = new Set<string>();

  const healOptions = rngShuffle(
    rng,
    available.filter((modifier) => modifier.delta === 0),
  );
  addFirstAvailable(selected, selectedIds, healOptions);

  const shuffledDeltas = rngShuffle(rng, [...NON_HEAL_DELTAS]);
  for (const delta of shuffledDeltas) {
    if (selected.length >= OFFER_SIZE) break;
    const bucket = rngShuffle(
      rng,
      available.filter((modifier) => modifier.delta === delta),
    );
    addFirstAvailable(selected, selectedIds, bucket);
  }

  const filler = rngShuffle(rng, available);
  for (const modifier of filler) {
    if (selected.length >= OFFER_SIZE) break;
    addModifier(selected, selectedIds, modifier);
  }

  return selected.slice(0, OFFER_SIZE);
}

function canOfferModifier(run: RunState, modifier: ModifierDef): boolean {
  return modifier.exclusiveTag === undefined || !run.hasExclusive(modifier.exclusiveTag);
}

function addFirstAvailable(
  selected: ModifierDef[],
  selectedIds: Set<string>,
  options: readonly ModifierDef[],
): void {
  for (const modifier of options) {
    if (addModifier(selected, selectedIds, modifier)) return;
  }
}

function addModifier(
  selected: ModifierDef[],
  selectedIds: Set<string>,
  modifier: ModifierDef,
): boolean {
  if (selectedIds.has(modifier.id)) return false;
  selected.push(modifier);
  selectedIds.add(modifier.id);
  return true;
}
