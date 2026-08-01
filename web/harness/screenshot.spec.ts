import { test, expect, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

const OUT = resolve('harness/frames');
mkdirSync(OUT, { recursive: true });

type Scenario =
  | 'menu'
  | 'character_select'
  | 'combat'
  | 'mage_combat'
  | 'orb_carry'
  | 'dps_window'
  | 'dice_roll_ui'
  | 'modifier_choice'
  | 'final_boss'
  | 'victory'
  | 'death';

async function waitForGame(page: Page): Promise<void> {
  await page.goto('/');
  await page.waitForFunction(() => {
    const api = (window as unknown as { __ALEARIS__?: { ready?: boolean } }).__ALEARIS__;
    return api?.ready === true;
  }, null, { timeout: 60_000 });
}

async function setScenario(page: Page, scenario: Scenario): Promise<void> {
  await page.evaluate(async (s) => {
    const api = (window as unknown as { __ALEARIS__: { setScenario: (x: string) => Promise<void> } }).__ALEARIS__;
    await api.setScenario(s);
  }, scenario);
  await page.waitForTimeout(400);
}

async function capture(page: Page, name: string): Promise<void> {
  const path = resolve(OUT, `${name}.png`);
  await page.screenshot({ path, fullPage: true, type: 'png' });
}

const SCENARIOS: Scenario[] = [
  'menu',
  'character_select',
  'combat',
  'mage_combat',
  'modifier_choice',
  'orb_carry',
  'dps_window',
  'dice_roll_ui',
  'final_boss',
  'victory',
  'death',
];

test.describe('Alearis screenshot harness', () => {
  test('captures retina frames for critic scenarios', async ({ page }) => {
    await waitForGame(page);

    for (const scenario of SCENARIOS) {
      await setScenario(page, scenario);
      await capture(page, scenario);

      // Alternate slight camera nudge via canvas focus — second angle
      await page.mouse.move(400, 400);
      await page.waitForTimeout(100);
      await capture(page, `${scenario}_alt`);
    }

    // Sanity: menu frame exists and is non-trivial
    const menu = resolve(OUT, 'menu.png');
    const fs = await import('node:fs');
    expect(fs.statSync(menu).size).toBeGreaterThan(20_000);
  });
});
