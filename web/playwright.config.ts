import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './harness',
  // The harness renders twenty retina frames of a shader-heavy scene through
  // software GL, at roughly six seconds each. 120s left it one screenshot short.
  timeout: 200_000,
  expect: { timeout: 30_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'harness/report' }]],
  use: {
    baseURL: 'http://localhost:5173',
    viewport: { width: 2560, height: 1440 },
    deviceScaleFactor: 2,
    colorScheme: 'dark',
  },
  webServer: {
    command: 'npm run dev -- --host localhost --port 5173',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  outputDir: 'harness/output',
});
