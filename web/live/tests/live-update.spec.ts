import { test, expect, type Page } from "@playwright/test";

async function replaceText(page: Page, text: string) {
  await page.locator(".cm-content").fill(text);
}

async function lastReply(page: Page) {
  return page.evaluate(() => (window as any).__liveReplies.at(-1));
}

// Waiting for a new revision prevents the previous edit's reply from passing
// the next assertion while its debounced evaluation is still pending.
async function edit(page: Page, text: string) {
  const previous = (await lastReply(page)).revision;
  await replaceText(page, text);
  await expect.poll(async () => (await lastReply(page)).revision).toBeGreaterThan(previous);
  return lastReply(page);
}

async function start(page: Page, text: string) {
  await replaceText(page, text);
  await page.locator("#start").click();
  await expect.poll(() => lastReply(page)).toMatchObject({ operation: "restart", appliedAtSample: 0 });
  return lastReply(page);
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    (window as any).__liveReplies = [];
    const Original = window.AudioWorkletNode;
    window.AudioWorkletNode = class extends Original {
      constructor(context: BaseAudioContext, name: string, options?: AudioWorkletNodeOptions) {
        super(context, name, options);
        this.port.addEventListener("message", ({ data }) => {
          if (/^((pattern|song)-(updated|error)|playback-(restarted|error))$/.test(data.type)) {
            (window as any).__liveReplies.push(data);
          }
        });
        this.port.start();
      }
    };
  });
  await page.goto("/");
});

test("editing and recovering from a parse error preserve transport", async ({ page }) => {
  await start(page, 'note("60").slow(8)');
  const updated = await edit(page, 'note("72").slow(8)');
  expect(updated).toMatchObject({ type: "pattern-updated", operation: "update" });
  expect(updated.appliedAtSample).toBeGreaterThan(0);
  expect(await edit(page, 'note(')).toMatchObject({ type: "pattern-error" });
  const recovered = await edit(page, 'note("67").slow(8)');
  expect(recovered).toMatchObject({ type: "pattern-updated", operation: "update" });
  expect(recovered.appliedAtSample).toBeGreaterThan(updated.appliedAtSample);
});

test("Restart current plays the applied score while leaving invalid editor text intact", async ({ page }) => {
  const applied = await start(page, 'note("67").slow(8)');
  expect(await edit(page, 'note(')).toMatchObject({ type: "pattern-error" });
  await page.locator("#restart").click();
  await expect.poll(() => lastReply(page)).toMatchObject({
    type: "playback-restarted", scoreRevision: applied.revision, appliedAtSample: 0,
  });
  await expect(page.locator(".cm-content")).toHaveText("note(");
});

test("song content edits continue, but a new layout requires Apply from beginning", async ({ page }) => {
  await page.locator("#mode-song").click();
  await start(page, 'song(section("a",8,note("60")),part("a1","a"))');
  const updated = await edit(page, 'song(section("a",8,note("72")),part("a1","a"))');
  expect(updated).toMatchObject({ type: "song-updated", operation: "update" });
  expect(updated.appliedAtSample).toBeGreaterThan(0);
  const rejected = await edit(page, 'song(section("a",9,note("72")),part("a1","a"))');
  expect(rejected).toMatchObject({ type: "song-error" });
  expect(rejected.message).toContain("restart required");
  await page.locator("#apply-restart").click();
  await expect.poll(() => lastReply(page)).toMatchObject({
    type: "song-updated", operation: "restart", appliedAtSample: 0,
  });
});
