import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './harness',
  timeout: 120_000,
  expect: { timeout: 30_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'harness/report' }]],
  use: {
    baseURL: 'http://127.0.0.1:5173',
    viewport: { width: 2560, height: 1440 },
    deviceScaleFactor: 2,
    colorScheme: 'dark',
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://127.0.0.1:5173',
    reuseExistingServer: true,
    timeout: 120_000,
  },
  outputDir: 'harness/output',
});
