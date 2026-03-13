/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
  testDir: './playwright-tests',
  timeout: 15_000,
  reporter: 'line',
  use: {
    baseURL: 'http://127.0.0.1:8090',
    browserName: 'chromium',
    headless: true,
  },
  webServer: {
    command: "bash -lc 'moon build --target wasm-gc --release && ./playwright-serve.sh 8090'",
    url: 'http://127.0.0.1:8090',
    reuseExistingServer: true,
    timeout: 30_000,
  },
};

module.exports = config;
