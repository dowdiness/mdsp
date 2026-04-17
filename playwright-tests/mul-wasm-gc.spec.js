const { test, expect } = require('@playwright/test');

// Counter-evidence to the former "Mul produces near-zero in wasm-gc" memory.
// Instantiates moonbit_dsp_test.wasm directly in the page context (no
// AudioWorklet) and calls mul_adsr_peak, which builds
// [osc(Sine, 440), adsr(5,5,0.5,50) ms, mul(0,1), output(2)],
// gate_on(1), processes one 128-sample block, and returns max abs sample.
//
// At 48 kHz/128 samples with a 5 ms attack, the ADSR envelope reaches ~0.53
// by the end of the block, and the 440 Hz sine covers ~1.16 cycles with peak
// 1.0. The true product |sine × envelope| should peak in a tight band just
// below the envelope ceiling — roughly 0.45.
//
// The bounds below are chosen to DISCRIMINATE multiplication from other
// candidate behaviors of this graph:
//   - pass-through of osc (≈ 1.0)               → fails upper bound
//   - pass-through of adsr (≈ 0.53)             → fails upper bound
//   - zero / near-zero (old "broken Mul" claim) → fails lower bound
// Only an actual per-sample multiply falls in the [0.42, 0.50] window.
test('Mul in wasm-gc release: [osc, adsr(ms), mul, output] peak lies in the multiply-specific band', async ({ page }) => {
  await page.goto('/');
  const result = await page.evaluate(async () => {
    const response = await fetch('moonbit_dsp_test.wasm');
    if (!response.ok) {
      return { error: `fetch failed: ${response.status}` };
    }
    const bytes = await response.arrayBuffer();
    const module = await WebAssembly.compile(bytes);
    const exports = WebAssembly.Module.exports(module).map((e) => e.name);
    const imports = {
      spectest: { print_char() {} },
      'moonbit:ffi': {
        make_closure(funcref, closure) {
          return funcref.bind(null, closure);
        },
      },
    };
    const instance = await WebAssembly.instantiate(module, imports);
    if (typeof instance.exports.mul_adsr_peak !== 'function') {
      return { error: 'mul_adsr_peak export missing', exports };
    }
    return { value: instance.exports.mul_adsr_peak(48000, 128) };
  });
  expect(result.error, result.error || '').toBeFalsy();
  expect(result.value, `peak=${result.value}`).toBeGreaterThan(0.42);
  expect(result.value, `peak=${result.value}`).toBeLessThan(0.50);
});
