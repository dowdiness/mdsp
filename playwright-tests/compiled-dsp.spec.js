const { test, expect } = require('@playwright/test');

const PAN_CENTER_GAIN = 0.7071067811865476;

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

async function currentTelemetry(page) {
  return page.evaluate(() => window.__mdspTelemetry);
}

function previewEnergy(samples) {
  return samples.reduce((sum, sample) => sum + Math.abs(sample), 0);
}

function previewVariation(samples) {
  let total = 0;
  for (let index = 1; index < samples.length; index += 1) {
    total += Math.abs(samples[index] - samples[index - 1]);
  }
  return total;
}

async function startAudio(page, path) {
  await page.goto(path);
  await page.click('#startBtn');
}

test('browser demo first render proves CompiledStereoDsp feedback recurrence', async ({ page }) => {
  await startAudio(page, '/?freq=0&delaySamples=0');
  await expect(page.locator('#status')).toContainText('CompiledStereoDsp block runtime');
  await expect
    .poll(async () => (await firstTelemetry(page))?.sequence || 0, { timeout: 10_000 })
    .toBeGreaterThan(0);
  const telemetry = await firstTelemetry(page);

  expect(telemetry.freq).toBeCloseTo(0, 9);
  expect(telemetry.leftPreview[0]).toBeGreaterThan(0.001);
  expect(telemetry.leftPreview[1]).toBeGreaterThan(telemetry.leftPreview[0]);
  expect(telemetry.leftPreview[2]).toBeGreaterThan(telemetry.leftPreview[1]);
  expect(telemetry.leftPreview[3]).toBeGreaterThan(telemetry.leftPreview[2]);
  expect(telemetry.leftPreview[0]).toBeLessThan(0.3 * PAN_CENTER_GAIN);
  expect(telemetry.rightPreview[0]).toBeCloseTo(telemetry.leftPreview[0], 9);
  expect(telemetry.rightPreview[3]).toBeCloseTo(telemetry.leftPreview[3], 9);
});

test('browser demo first render proves StereoDelay startup offset on feedback graph', async ({ page }) => {
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

test('browser demo retunes stereo feedback gain and reacts to pan', async ({ page }) => {
  await startAudio(page, '/');
  await expect(page.locator('#status')).toContainText('CompiledStereoDsp block runtime');
  await expect
    .poll(async () => (await currentTelemetry(page))?.sequence || 0, { timeout: 10_000 })
    .toBeGreaterThan(0);
  const initialTelemetry = await currentTelemetry(page);

  await setRangeValue(page, '#gainSlider', 50);
  await expect(page.locator('#gainValue')).toHaveText('50');
  await expect
    .poll(async () => {
      const telemetry = await currentTelemetry(page);
      if (!telemetry) {
        return 0;
      }
      return telemetry.sequence > initialTelemetry.sequence &&
        Math.abs(telemetry.gain - 0.5) < 0.000001
        ? telemetry.overallPeak - initialTelemetry.overallPeak
        : 0;
    }, { timeout: 10_000 })
    .toBeGreaterThan(0.4);
  const retunedTelemetry = await currentTelemetry(page);
  expect(retunedTelemetry.gain).toBeCloseTo(0.5, 6);
  expect(retunedTelemetry.overallPeak).toBeGreaterThan(0.7);
  expect(retunedTelemetry.overallPeak).toBeLessThan(1.01);
  expect(retunedTelemetry.leftPreview.every(Number.isFinite)).toBeTruthy();

  await setRangeValue(page, '#freqSlider', 660);
  await expect(page.locator('#freqValue')).toHaveText('660');
  await expect
    .poll(async () => {
      const telemetry = await currentTelemetry(page);
      if (!telemetry) {
        return 0;
      }
      return Math.abs(telemetry.freq - 660) < 0.000001 ? telemetry.overallPeak : 0;
    }, { timeout: 10_000 })
    .toBeGreaterThan(0.01);

  await setRangeValue(page, '#delaySlider', 0);
  await expect(page.locator('#delayValue')).toHaveText('0');
  await expect
    .poll(async () => {
      const telemetry = await currentTelemetry(page);
      if (!telemetry) {
        return -1;
      }
      return Math.abs(telemetry.delaySamples);
    }, { timeout: 10_000 })
    .toBeLessThan(0.000001);

  await setRangeValue(page, '#cutoffSlider', 180);
  await expect(page.locator('#cutoffValue')).toHaveText('180');
  await expect
    .poll(async () => {
      const telemetry = await currentTelemetry(page);
      if (!telemetry) {
        return 0;
      }
      return Math.abs(telemetry.cutoff - 180) < 0.000001
        ? previewVariation(telemetry.leftPreview)
        : 0;
    }, { timeout: 10_000 })
    .toBeGreaterThan(0.0001);
  const lowCutoffTelemetry = await currentTelemetry(page);
  const lowCutoffVariation = previewVariation(lowCutoffTelemetry.leftPreview);

  await setRangeValue(page, '#cutoffSlider', 4000);
  await expect(page.locator('#cutoffValue')).toHaveText('4000');
  await expect
    .poll(async () => {
      const telemetry = await currentTelemetry(page);
      if (!telemetry) {
        return 0;
      }
      return Math.abs(telemetry.cutoff - 4000) < 0.000001
        ? previewVariation(telemetry.leftPreview) - lowCutoffVariation
        : 0;
    }, { timeout: 10_000 })
    .toBeGreaterThan(0.0005);
  const highCutoffTelemetry = await currentTelemetry(page);
  const highCutoffVariation = previewVariation(highCutoffTelemetry.leftPreview);

  expect(previewEnergy(lowCutoffTelemetry.leftPreview)).toBeGreaterThan(0.01);
  expect(highCutoffVariation).toBeGreaterThan(lowCutoffVariation);

  await setRangeValue(page, '#panSlider', -100);
  await expect(page.locator('#panValue')).toHaveText('-100');
  await expect
    .poll(async () => {
      const telemetry = await currentTelemetry(page);
      if (!telemetry) {
        return 0;
      }
      return telemetry.pan <= -1 &&
        telemetry.sequence > retunedTelemetry.sequence
        ? telemetry.leftPeak - telemetry.rightPeak
        : 0;
    }, { timeout: 10_000 })
    .toBeGreaterThan(0.8);

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
      const telemetry = await currentTelemetry(page);
      if (!telemetry) {
        return 0;
      }
      return telemetry.pan >= 1 ? telemetry.rightPeak - telemetry.leftPeak : 0;
    }, { timeout: 10_000 })
    .toBeGreaterThan(0.8);
});

test('browser demo falls back to CompiledDsp when stereo init fails', async ({ page }) => {
  await startAudio(page, '/?forceStereoInitFailure=1&freq=440');
  await expect(page.locator('#status')).toContainText('CompiledDsp block runtime');
  await expect(page.locator('#status')).not.toContainText('Processor init failed');
  await expect
    .poll(async () => (await firstTelemetry(page))?.sequence || 0, { timeout: 10_000 })
    .toBeGreaterThan(0);
  const initialTelemetry = await firstTelemetry(page);

  expect(initialTelemetry.leftPreview[0]).toBeCloseTo(0.3, 6);
  expect(initialTelemetry.leftPreview[1]).toBeCloseTo(0.39, 6);
  expect(initialTelemetry.leftPreview[2]).toBeCloseTo(0.417, 6);
  expect(initialTelemetry.leftPreview[3]).toBeCloseTo(0.4251, 6);
  expect(initialTelemetry.rightPreview[0]).toBeCloseTo(initialTelemetry.leftPreview[0], 9);
  expect(initialTelemetry.rightPreview[3]).toBeCloseTo(initialTelemetry.leftPreview[3], 9);

  await setRangeValue(page, '#gainSlider', 50);
  await expect(page.locator('#gainValue')).toHaveText('50');
  await expect
    .poll(async () => {
      const telemetry = await currentTelemetry(page);
      if (!telemetry) {
        return 0;
      }
      return telemetry.sequence > initialTelemetry.sequence &&
        Math.abs(telemetry.gain - 0.5) < 0.000001
        ? telemetry.sequence
        : 0;
    }, { timeout: 10_000 })
    .toBeGreaterThan(0);
  const retunedTelemetry = await currentTelemetry(page);

  expect(retunedTelemetry.gain).toBeCloseTo(0.5, 6);
  expect(retunedTelemetry.leftPreview[0]).toBeGreaterThan(0.7);
  expect(retunedTelemetry.leftPreview[3]).toBeGreaterThan(0.95);
  expect(retunedTelemetry.leftPreview.every(Number.isFinite)).toBeTruthy();
  expect(retunedTelemetry.overallPeak).toBeGreaterThan(0.95);
  expect(retunedTelemetry.overallPeak).toBeLessThan(1.01);
});
