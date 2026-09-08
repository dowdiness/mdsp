// Build first: NEW_MOON_MOD=0 moon build browser --target wasm-gc --release
// Usage: node scripts/measure-worklet-preparation.cjs [output.json] [rounds=3]
const { chromium } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const rounds = Number(process.argv[3] || 3);
if (!Number.isInteger(rounds) || rounds < 1 || rounds > 20) throw new Error('rounds must be 1..20');
const root = path.resolve(__dirname, '..');
const wasm = fs.readFileSync(path.join(root, '_build/wasm-gc/release/build/browser/browser.wasm'));
const production = fs.readFileSync(path.join(root, 'web/scheduler-processor.js'), 'utf8');
const instrumentation = fs.readFileSync(path.join(root, 'scripts/worklet-measurement/instrumentation.js'), 'utf8');
const routes = {
  '/': ['text/html', '<!doctype html><title>AudioWorklet measurement</title>'],
  '/processor.js': ['text/javascript', production + '\n' + instrumentation],
  '/playback-controller.js': ['text/javascript', fs.readFileSync(path.join(root, 'web/playback-controller.js'))],
  '/engine.wasm': ['application/wasm', wasm],
};
const server = http.createServer((req, res) => {
  const route = routes[req.url];
  if (!route) { res.writeHead(404).end(); return; }
  res.writeHead(200, { 'Content-Type': route[0], 'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-store' });
  res.end(route[1]);
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const flags = ['--autoplay-policy=no-user-gesture-required'];
  if (process.env.WORKLET_STATS_EXPERIMENTAL === '1') flags.push('--enable-blink-features=AudioContextPlayoutStats');
  const headless = process.env.WORKLET_HEADED !== '1';
  const browser = await chromium.launch({ headless, args: flags,
    ...(process.env.WORKLET_SYSTEM_CHROME === '1' ? { channel:'chrome' } : {}),
    ...(process.env.WORKLET_UNMUTED === '1' ? { ignoreDefaultArgs:['--mute-audio'] } : {}),
  });
  try {
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    const result = process.env.WORKLET_ACCEPTANCE === '1'
      ? await page.evaluate(require('./worklet-measurement/acceptance.cjs').run, require('./worklet-measurement/orbit.cjs'))
      : await page.evaluate(async rounds => {
      const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
      const module = await WebAssembly.compile(await (await fetch('/engine.wasm')).arrayBuffer());
      const lengths = [12,12,24,48,24,23,1,24,24,24,12,12];
      function score(variant) {
        const body = `stack(note("${variant % 2 ? 'E4 G4 B4' : 'E4 G4 A4'}").slow(3),note("D5 A4 G4 E5").slow(4).jux(rev),chord("Cmaj9 Am7 Fmaj9 G6").slow(48),note("C2 A1 F2 G2").slow(48),s("bd"),s("hh(5,8)").slow(4).degradeBy(0.12),s("cp(2,4,1)").slow(4))`;
        return 'song(' + lengths.map((n,i) => `section("s${i}",${n},${body})`).concat(lengths.map((_,i) => `part("p${i}","s${i}")`)).join(',') + ')';
      }
      function stats(a) {
        a = Array.from(a).sort((a,b) => a-b);
        return { count:a.length, mean_ms:a.length ? a.reduce((x,y)=>x+y,0)/a.length : null,
          p95_ms:a.length ? a[Math.min(a.length-1,Math.ceil(a.length*.95)-1)] : null,
          max_ms:a.length ? a.at(-1) : null, over_block_budget:a.filter(x=>x>128/48).length };
      }
      function outputStats(ctx) {
        const value = ctx.playbackStats ?? ctx.playoutStats;
        return value ? { api:ctx.playbackStats ? 'playbackStats' : 'playoutStats', ...value.toJSON() } : null;
      }
      const results = [];
      const modes = ['baseline', 'prepare-only', 'apply-score', 'positive-control'];
      for (let round=0; round<rounds; round++) {
        // Rotate order to reduce systematic warm-up/order effects.
        for (let index=0; index<modes.length; index++) {
          const mode = modes[(index+round)%modes.length];
          const ctx = new AudioContext({sampleRate:48000, latencyHint:'interactive'});
          await ctx.audioWorklet.addModule('/processor.js');
          const node = new AudioWorkletNode(ctx, 'moondsp-measured', { outputChannelCount:[2],
            processorOptions:{wasmModule:module,initialGain:0.1} });
          const replies = [], errors = [];
          node.port.onmessage = ({data}) => { replies.push(data); if (data.type==='error' || data.type.endsWith('-error')) errors.push(data); };
          node.onprocessorerror = () => errors.push({type:'processorerror'});
          // Keep the destination path active; zero gain could permit silence optimizations.
          node.connect(ctx.destination);
          await ctx.resume();
          async function reply(type) {
            const until = performance.now()+10000;
            while (!replies.some(x=>x.type===type)) {
              if (errors.length || performance.now()>until) throw new Error(JSON.stringify({type,errors}));
              await wait(10);
            }
            return replies.splice(replies.findIndex(x=>x.type===type),1)[0];
          }
          await reply('ready');
          node.port.postMessage({type:'apply-score',mode:'song',policy:'restart',text:score(0),revision:0});
          await reply('song-updated');
          await wait(2000);
          const before = outputStats(ctx), timeBefore = ctx.currentTime;
          node.port.postMessage({type:'measure-start'});
          await reply('measure-started');
          const wallStart = performance.now();
          for (let n=0;n<24;n++) {
            if (mode==='prepare-only') node.port.postMessage({type:mode,text:score(n)});
            if (mode==='apply-score') node.port.postMessage({type:mode,mode:'song',policy:'continue',text:score(n),revision:n+1});
            if (mode==='positive-control') node.port.postMessage({type:mode});
            await wait(250);
          }
          // Stats update at most once a second; allow late destination reports to settle.
          await wait(1500);
          const after = outputStats(ctx);
          const wall_ms = performance.now()-wallStart, audio_seconds = ctx.currentTime-timeBefore;
          node.port.postMessage({type:'measure-stop'});
          const measured = await reply('measurement');
          const applied = replies.filter(x=>x.type==='song-updated').length;
          const expected = mode==='prepare-only' || mode==='apply-score' ? 24 : 0;
          if (measured.overflow || errors.length || measured.prepares!==expected ||
              (mode==='apply-score' && applied!==24)) throw new Error(JSON.stringify({measured,errors,applied}));
          results.push({round,mode,wall_ms,audio_seconds,sample_rate:ctx.sampleRate,base_latency:ctx.baseLatency,
            output_latency:ctx.outputLatency,clock:measured.clock,render:stats(measured.renderTimes),
            callback_gap:stats(measured.gaps.slice(1)),preparation:stats(measured.preparations),handler:stats(measured.handlers),
            applied_receipts:applied,before,after});
          await ctx.close();
        }
      }
      return {schema_version:1,user_agent:navigator.userAgent,isolated:crossOriginIsolated,visibility:document.visibilityState,
        workload:{sections:12,cycles:240,characters:score(0).length,requests:24,interval_ms:250,warmup_ms:2000,settle_ms:1500},results};
    }, rounds);
    result.headless = headless;
    result.system_chrome = process.env.WORKLET_SYSTEM_CHROME === '1';
    result.unmuted = process.env.WORKLET_UNMUTED === '1';
    result.experimental_stats = process.env.WORKLET_STATS_EXPERIMENTAL === '1';
    result.base_commit = execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim();
    result.wasm_sha256 = crypto.createHash('sha256').update(wasm).digest('hex');
    const json = JSON.stringify(result,null,2)+'\n';
    if (process.argv[2]) fs.writeFileSync(process.argv[2],json); else process.stdout.write(json);
  } finally { await browser.close(); }
})().catch(e=>{ console.error(e); process.exitCode=1; }).finally(()=>server.close());
