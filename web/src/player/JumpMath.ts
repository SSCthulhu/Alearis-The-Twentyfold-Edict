export const DEFAULT_JUMP_SPEED = 9.6;
export const DEFAULT_DOUBLE_JUMP_SPEED = 9.0;
export const DEFAULT_GRAVITY = 22.5;
export const MAX_SAFE_GRAVITY_MULTIPLIER = 1.15;
export const MAX_ADJACENT_PLATFORM_STEP = 2.35;
export const MIN_VALIDATED_DOUBLE_JUMP_CLEARANCE = 3.2;

/** Ballistic rise above the take-off point for an initial upward velocity. */
export function maxJumpHeight(initialVelocity: number, gravity: number): number {
  if (gravity <= 0) throw new RangeError('gravity must be greater than zero');
  const velocity = Math.max(0, initialVelocity);
  return velocity * velocity / (2 * gravity);
}

/**
 * Conservative two-stage ceiling: jump once, then spend the second jump at
 * the first apex. This is the same clearance model used to validate arenas.
 */
export function maxDoubleJumpHeight(
  jumpSpeed: number,
  doubleJumpSpeed: number,
  gravity: number,
): number {
  return maxJumpHeight(jumpSpeed, gravity) + maxJumpHeight(doubleJumpSpeed, gravity);
}

export function assertJumpConstants(): void {
  const worstCaseGravity = DEFAULT_GRAVITY * MAX_SAFE_GRAVITY_MULTIPLIER;
  const clearance = maxDoubleJumpHeight(
    DEFAULT_JUMP_SPEED,
    DEFAULT_DOUBLE_JUMP_SPEED,
    worstCaseGravity,
  );
  if (clearance < MIN_VALIDATED_DOUBLE_JUMP_CLEARANCE) {
    throw new Error(
      `Default double-jump clearance ${clearance.toFixed(3)} is below ` +
      `${MIN_VALIDATED_DOUBLE_JUMP_CLEARANCE.toFixed(3)}`,
    );
  }
  if (MAX_ADJACENT_PLATFORM_STEP >= MIN_VALIDATED_DOUBLE_JUMP_CLEARANCE) {
    throw new Error('Arena step cap must leave margin below double-jump clearance');
  }
}

assertJumpConstants();
