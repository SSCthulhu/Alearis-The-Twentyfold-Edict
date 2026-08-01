import { expect, test, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

const FRAME_DIR = resolve('harness/frames');
mkdirSync(FRAME_DIR, { recursive: true });

type ClassId = 'knight' | 'rogue' | 'mage';

interface PlayerState {
  x: number;
  y: number;
  grounded: boolean;
  classId: string;
  hp: number;
  alive: boolean;
  jumpedLastFrame?: boolean;
}

interface RunTelemetry {
  phase: string;
  kills: number;
  floor: number;
  world: number;
  classId: string;
  enemyAlive: number;
}

interface DebugApi {
  ready: boolean;
  setScenario: (scenario: string) => Promise<void>;
  startRun: (classId?: ClassId, seed?: number) => void;
  getPlayerState: () => PlayerState | null;
  getRunTelemetry: () => RunTelemetry;
  getRunSnapshot: () => Record<string, unknown>;
}

declare global {
  interface Window {
    __ALEARIS__?: DebugApi;
  }
}

async function waitForGame(page: Page): Promise<void> {
  await page.goto('/');
  await page.waitForFunction(() => window.__ALEARIS__?.ready === true, null, {
    timeout: 60_000,
  });
  // setScenario awaits the shared KayKit preload before constructing the floor.
  await page.evaluate(async () => window.__ALEARIS__?.setScenario('combat'));
  await waitForFloor(page, 'knight');
}

async function startClass(page: Page, classId: ClassId, seed: number): Promise<void> {
  await page.evaluate(
    ({ selectedClass, runSeed }) => window.__ALEARIS__?.startRun(selectedClass, runSeed),
    { selectedClass: classId, runSeed: seed },
  );
  await waitForFloor(page, classId);
}

async function waitForFloor(page: Page, classId: ClassId): Promise<void> {
  await page.waitForFunction(
    (selectedClass) => {
      const api = window.__ALEARIS__;
      const player = api?.getPlayerState();
      const run = api?.getRunTelemetry();
      return (
        player?.classId === selectedClass &&
        player.alive &&
        run?.classId === selectedClass &&
        run.phase === 'combat' &&
        run.enemyAlive > 0
      );
    },
    classId,
    { timeout: 60_000 },
  );
  await expect
    .poll(async () => (await getPlayerState(page))?.grounded, { timeout: 10_000 })
    .toBe(true);
}

async function getPlayerState(page: Page): Promise<PlayerState | null> {
  return page.evaluate(() => window.__ALEARIS__?.getPlayerState() ?? null);
}

async function getTelemetry(page: Page): Promise<RunTelemetry> {
  return page.evaluate(() => {
    const telemetry = window.__ALEARIS__?.getRunTelemetry();
    if (!telemetry) throw new Error('Alearis debug telemetry is unavailable');
    return telemetry;
  });
}

async function screenshot(page: Page, name: string): Promise<void> {
  await page.screenshot({
    path: resolve(FRAME_DIR, `playtest-${name}.png`),
    fullPage: true,
    type: 'png',
  });
}

async function sampleHeight(page: Page, samples: number, intervalMs: number): Promise<number> {
  let maxY = Number.NEGATIVE_INFINITY;
  for (let i = 0; i < samples; i += 1) {
    await page.waitForTimeout(intervalMs);
    const state = await getPlayerState(page);
    if (state) maxY = Math.max(maxY, state.y);
  }
  return maxY;
}

/**
 * Uses long presses, early releases, and a forgiving double-jump. Nothing here
 * depends on a particular render frame or a platform-edge pixel coordinate.
 */
async function casualPlatformJumps(page: Page): Promise<{ startY: number; maxY: number }> {
  const initial = await getPlayerState(page);
  if (!initial) throw new Error('Player did not exist before jump test');

  let maxY = initial.y;
  for (const direction of ['d', 'a', 'd']) {
    await page.keyboard.down(direction);
    await page.keyboard.down('Space');
    maxY = Math.max(maxY, await sampleHeight(page, 5, 110));
    await page.keyboard.up('Space');
    await page.waitForTimeout(180);
    await page.keyboard.press('Space', { delay: 180 });
    maxY = Math.max(maxY, await sampleHeight(page, 5, 110));
    await page.keyboard.up(direction);
    await page.waitForTimeout(350);
  }

  return { startY: initial.y, maxY };
}

async function useClassKit(page: Page, classId: ClassId): Promise<void> {
  await page.keyboard.press('j', { delay: 140 });
  await page.waitForTimeout(420);
  await page.keyboard.press('k', { delay: 170 });
  await page.waitForTimeout(760);
  await page.keyboard.press('l', { delay: 120 });
  await page.waitForTimeout(280);
  await page.keyboard.press('u', { delay: 160 });
  await page.waitForTimeout(classId === 'mage' ? 1_100 : 850);
}

async function runCombatSmoke(page: Page): Promise<void> {
  await startClass(page, 'mage', 0xc0b471);
  const before = await getTelemetry(page);
  const beforeSnapshot = await page.evaluate(() => window.__ALEARIS__?.getRunSnapshot());
  const beforeMeter = Number(beforeSnapshot?.meter ?? 0);

  // Walk into the broad first-platform engagement zone, then cast the mage's
  // large storm from safe ground. Follow-up attacks tolerate enemy movement.
  await page.keyboard.down('d');
  await page.waitForTimeout(650);
  await page.keyboard.up('d');
  await page.keyboard.press('u', { delay: 180 });

  for (let i = 0; i < 12; i += 1) {
    const telemetry = await getTelemetry(page);
    if (telemetry.kills > before.kills) break;
    await page.keyboard.press(i % 3 === 0 ? 'k' : 'j', { delay: 120 });
    if (i === 4) {
      await page.keyboard.down('d');
      await page.keyboard.press('Space', { delay: 180 });
      await page.waitForTimeout(500);
      await page.keyboard.up('d');
    }
    await page.waitForTimeout(480);
  }

  await expect.poll(async () => (await getTelemetry(page)).kills, { timeout: 10_000 }).toBeGreaterThan(before.kills);
  const after = await getTelemetry(page);
  expect(after.enemyAlive).toBeLessThan(before.enemyAlive);

  const afterSnapshot = await page.evaluate(() => window.__ALEARIS__?.getRunSnapshot());
  expect(Number(afterSnapshot?.meter ?? 0)).toBeGreaterThan(beforeMeter);
  await screenshot(page, 'combat-kill');
}

test.describe('Alearis automated gameplay playtest', () => {
  test('all classes can platform and fight with casual input timing', async ({ page }) => {
    test.setTimeout(300_000);
    const pageErrors: string[] = [];
    page.on('pageerror', (error) => pageErrors.push(error.message));

    await waitForGame(page);

    const classes: readonly ClassId[] = ['knight', 'rogue', 'mage'];
    for (const [index, classId] of classes.entries()) {
      await startClass(page, classId, 0xa1ea215 + index);

      if (classId === 'knight') {
        // A fresh floor must not drop or kill an untouched player.
        await page.waitForTimeout(20_000);
        const idleState = await getPlayerState(page);
        expect(idleState?.alive).toBe(true);
        expect(idleState?.hp).toBeGreaterThan(0);
      }

      const clearance = await casualPlatformJumps(page);
      expect(clearance.maxY - clearance.startY).toBeGreaterThan(1);
      const afterJumps = await getPlayerState(page);
      expect(afterJumps?.alive).toBe(true);
      await screenshot(page, `${classId}-platforming`);

      await useClassKit(page, classId);
      const afterAbilities = await getPlayerState(page);
      expect(afterAbilities?.alive).toBe(true);
      expect(pageErrors, `${classId} emitted page errors`).toEqual([]);

      if (classId === 'mage') {
        await screenshot(page, 'mage-light-heavy-ultimate');
      }
    }

    await runCombatSmoke(page);
    expect(pageErrors, 'Gameplay emitted page errors').toEqual([]);
  });
});
