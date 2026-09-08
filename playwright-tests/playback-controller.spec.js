const { test, expect } = require('@playwright/test');

test('playback receipts describe committed state across failed and superseded requests', async ({ page }) => {
  await page.goto('/');
  const replies = await page.evaluate(async () => {
    const { PlaybackController } = await import('/playback-controller.js');
    const { instance } = await WebAssembly.instantiate(
      await (await fetch('/moonbit_dsp.wasm')).arrayBuffer(),
      { spectest: { print_char() {} },
        'moonbit:ffi': { make_closure(fn, closure) { return fn.bind(null, closure); } } },
    );
    const wasm = instance.exports;
    if (!wasm.init_scheduler_graph(48000, 128)) throw new Error('init failed');
    const replies = [];
    const controller = new PlaybackController(wasm, reply => replies.push(reply));
    const apply = (revision, policy, text = 'note("60")') =>
      controller.handle({ type: 'apply-score', mode: 'pattern', revision, policy, text });
    const render = () => {
      if (!wasm.process_scheduler_block()) throw new Error('render failed');
      controller.didRender(128);
    };
    apply(1, 'restart');
    controller.handle({ type: 'restart-playback', revision: 2 });
    if (replies.some(reply => reply.type === 'pattern-updated')) throw new Error('premature receipt');
    render(); // Failed restart must retain the pending initial score.
    apply(3, 'continue', 'note("64")');
    apply(4, 'continue', 'note('); // Failed preparation must retain request 3.
    render();
    apply(5, 'continue', 'note("67")');
    apply(6, 'continue', 'note("72")');
    controller.handle({ type: 'restart-playback', revision: 7 });
    render(); // Restart must cancel both replacements and use applied score 3.
    return replies;
  });
  expect(replies).toEqual([
    expect.objectContaining({ type: 'playback-error', phase: 'restart', revision: 2 }),
    expect.objectContaining({ type: 'pattern-updated', revision: 1, scoreRevision: 1, appliedAtSample: 0, samplePosition: 128 }),
    expect.objectContaining({ type: 'pattern-error', phase: 'prepare', revision: 4 }),
    expect.objectContaining({ type: 'pattern-updated', revision: 3, scoreRevision: 3, appliedAtSample: 128, samplePosition: 256 }),
    { type: 'playback-superseded', revision: 5 },
    { type: 'playback-superseded', revision: 6 },
    expect.objectContaining({ type: 'playback-restarted', revision: 7, scoreRevision: 3, appliedAtSample: 0, samplePosition: 128 }),
  ]);
});
