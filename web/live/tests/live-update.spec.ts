import { test, expect, type Page } from "@playwright/test";

async function replaceText(page: Page, text: string) {
  await page.locator(".cm-content").fill(text);
}

async function lastReply(page: Page) {
  return page.evaluate(() => (window as any).__liveReplies.at(-1));
}

test("normal editor updates preserve transport; restart is explicit", async ({ page }) => {
  test.setTimeout(30_000);
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
  await replaceText(page, 'note("60").slow(8)');
  await page.locator("#start").click();
  await expect.poll(() => lastReply(page)).toMatchObject({ operation: "restart", appliedAtSample: 0 });
  await replaceText(page, 'note("72").slow(8)');
  await expect.poll(() => lastReply(page)).toMatchObject({ operation: "update" });
  const first = await lastReply(page);
  expect(first.samplePosition).toBeGreaterThan(0);
  await replaceText(page, 'note(');
  await expect.poll(() => lastReply(page)).toMatchObject({ type: "pattern-error" });
  await replaceText(page, 'note("67").slow(8)');
  await expect.poll(() => lastReply(page)).toMatchObject({ operation: "update" });
  expect((await lastReply(page)).samplePosition).toBeGreaterThan(first.samplePosition);
  const applied = await lastReply(page);
  await replaceText(page, 'note(');
  await expect.poll(() => lastReply(page)).toMatchObject({ type: "pattern-error" });
  await page.locator("#restart").click();
  await expect.poll(() => lastReply(page)).toMatchObject({ type: "playback-restarted", scoreRevision: applied.revision, appliedAtSample: 0 });
  await expect(page.locator(".cm-content")).toHaveText("note(");
  await page.locator("#mode-song").click();
  await replaceText(page, 'song(section("a",8,note("60")),part("a1","a"))');
  await expect.poll(() => lastReply(page)).toMatchObject({ type: "song-updated", operation: "restart" });
  await replaceText(page, 'song(section("a",8,note("72")),part("a1","a"))');
  await expect.poll(() => lastReply(page)).toMatchObject({ type: "song-updated", operation: "update" });
  expect((await lastReply(page)).samplePosition).toBeGreaterThan(0);
  await replaceText(page, 'song(section("a",9,note("72")),part("a1","a"))');
  await expect.poll(() => lastReply(page)).toMatchObject({ type: "song-error" });
  expect((await lastReply(page)).message).toContain("restart required");
  await page.locator("#apply-restart").click();
  await expect.poll(() => lastReply(page)).toMatchObject({ type: "song-updated", operation: "restart", appliedAtSample: 0 });

});
