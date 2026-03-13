const { test, expect } = require('@playwright/test');

async function setRangeValue(page, selector, value) {
  await page.locator(selector).evaluate((element, nextValue) => {
    element.value = String(nextValue);
    element.dispatchEvent(new Event('input', { bubbles: true }));
  }, value);
}

async function meterWidth(page) {
  return page.locator('#meterFill').evaluate((element) => {
    const width = element.style.width || '0';
    return Number.parseFloat(width);
  });
}

test('browser demo reports CompiledDsp mode and reacts to controls', async ({ page }) => {
  await page.goto('/');
  await page.click('#startBtn');
  await expect(page.locator('#status')).toContainText('CompiledDsp block runtime');

  await expect.poll(() => meterWidth(page), { timeout: 10_000 }).toBeGreaterThan(0.5);

  await setRangeValue(page, '#gainSlider', 0);
  await expect(page.locator('#gainValue')).toHaveText('0');
  await expect.poll(() => meterWidth(page), { timeout: 10_000 }).toBeLessThan(0.2);

  await setRangeValue(page, '#freqSlider', 660);
  await setRangeValue(page, '#gainSlider', 45);
  await expect(page.locator('#freqValue')).toHaveText('660');
  await expect(page.locator('#gainValue')).toHaveText('45');
  await expect.poll(() => meterWidth(page), { timeout: 10_000 }).toBeGreaterThan(0.5);
});
