const { test, expect } = require('@playwright/test');

async function setRangeValue(page, selector, value) {
  await page.locator(selector).evaluate((element, nextValue) => {
    element.value = String(nextValue);
    element.dispatchEvent(new Event('input', { bubbles: true }));
  }, value);
}

async function renderPeaks(page) {
  const [overall, left, right] = await Promise.all([
    page.locator('#renderPeakValue').textContent(),
    page.locator('#renderLeftPeakValue').textContent(),
    page.locator('#renderRightPeakValue').textContent(),
  ]);
  return {
    overall: Number.parseFloat(overall || '0'),
    left: Number.parseFloat(left || '0'),
    right: Number.parseFloat(right || '0'),
  };
}

async function firstTelemetry(page) {
  return page.evaluate(() => window.__mdspFirstTelemetry);
}

function previewEnergy(samples) {
  return samples.reduce((sum, sample) => sum + Math.abs(sample), 0);
}

async function startAudio(page, path) {
  await page.goto(path);
  await page.click('#startBtn');
}

test('browser demo first render proves StereoDelay startup offset', async ({ page }) => {
  await startAudio(page, '/?delaySamples=0');
  await expect
    .poll(async () => (await firstTelemetry(page))?.sequence || 0, { timeout: 10_000 })
    .toBeGreaterThan(0);
  const zeroDelayTelemetry = await firstTelemetry(page);
  const zeroDelayEnergy = previewEnergy(zeroDelayTelemetry.leftPreview);

  await startAudio(page, '/?delaySamples=24');
  await expect
    .poll(async () => (await firstTelemetry(page))?.sequence || 0, { timeout: 10_000 })
    .toBeGreaterThan(0);
  const delayedTelemetry = await firstTelemetry(page);
  const delayedLeftEnergy = previewEnergy(delayedTelemetry.leftPreview);
  const delayedRightEnergy = previewEnergy(delayedTelemetry.rightPreview);

  expect(zeroDelayEnergy).toBeGreaterThan(0.001);
  expect(delayedLeftEnergy).toBeLessThan(0.000000001);
  expect(delayedRightEnergy).toBeLessThan(0.000000001);
});

test('browser demo reports CompiledStereoDsp mode and reacts to pan', async ({ page }) => {
  await startAudio(page, '/');
  await expect(page.locator('#status')).toContainText('CompiledStereoDsp block runtime');

  await expect
    .poll(async () => (await renderPeaks(page)).overall, { timeout: 10_000 })
    .toBeGreaterThan(0.02);

  await setRangeValue(page, '#freqSlider', 660);
  await setRangeValue(page, '#cutoffSlider', 180);
  await setRangeValue(page, '#gainSlider', 55);
  await expect(page.locator('#cutoffValue')).toHaveText('180');
  await expect(page.locator('#gainValue')).toHaveText('55');
  await expect(page.locator('#freqValue')).toHaveText('660');
  await expect
    .poll(async () => (await renderPeaks(page)).overall, { timeout: 10_000 })
    .toBeGreaterThan(0.02);
  const lowCutoffPeak = (await renderPeaks(page)).overall;

  await setRangeValue(page, '#cutoffSlider', 4000);
  await expect(page.locator('#cutoffValue')).toHaveText('4000');
  await expect
    .poll(async () => (await renderPeaks(page)).overall - lowCutoffPeak, { timeout: 10_000 })
    .toBeGreaterThan(0.03);

  await setRangeValue(page, '#panSlider', -100);
  await expect(page.locator('#panValue')).toHaveText('-100');
  await expect
    .poll(async () => {
      const { left, right } = await renderPeaks(page);
      return left - right;
    }, { timeout: 10_000 })
    .toBeGreaterThan(0.2);

  await setRangeValue(page, '#panSlider', 0);
  await expect(page.locator('#panValue')).toHaveText('0');
  await expect
    .poll(async () => {
      const { left, right } = await renderPeaks(page);
      return Math.abs(left - right);
    }, { timeout: 10_000 })
    .toBeLessThan(0.05);

  await setRangeValue(page, '#panSlider', 100);
  await expect(page.locator('#panValue')).toHaveText('100');
  await expect
    .poll(async () => {
      const { left, right } = await renderPeaks(page);
      return right - left;
    }, { timeout: 10_000 })
    .toBeGreaterThan(0.2);
});

test('browser demo falls back to CompiledDsp when stereo init fails', async ({ page }) => {
  await startAudio(page, '/?forceStereoInitFailure=1');
  await expect(page.locator('#status')).toContainText('CompiledDsp block runtime');
  await expect(page.locator('#status')).not.toContainText('Processor init failed');
  await expect
    .poll(async () => (await renderPeaks(page)).overall, { timeout: 10_000 })
    .toBeGreaterThan(0.02);

  await setRangeValue(page, '#gainSlider', 40);
  await setRangeValue(page, '#freqSlider', 550);
  await expect(page.locator('#gainValue')).toHaveText('40');
  await expect(page.locator('#freqValue')).toHaveText('550');
  await expect
    .poll(async () => (await renderPeaks(page)).overall, { timeout: 10_000 })
    .toBeGreaterThan(0.02);
});
