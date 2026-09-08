// PROTOTYPE: a finite prepared score and game scenes share one musical clock.
import {Q, BAR} from './prepare.mjs';
export {Q, BAR};
const freeze = Object.freeze;
export function ownBundle(b) {
  if (!b || !Number.isSafeInteger(b.revision) || b.revision < 1 || !Number.isSafeInteger(b.length) || b.length <= 0 || b.length > 6144000) throw Error('invalid score');
  let total = 0;
  const ownRows = (rows, length) => {
    if (!Array.isArray(rows) || rows.length > 10000) throw Error('event capacity');
    let last = -1, previousBlock = -1, count = 0;
    return freeze(rows.map(e => {
      if (!e || ![e.at,e.end,e.route,e.hz,e.gain,e.pan].every(Number.isFinite) || e.at < 0 || e.at >= length || e.at < last || e.end <= e.at || e.end > 24576000 || !Number.isInteger(e.route) || e.route < 0 || e.route > 5 || e.hz < 0 || e.hz > 20000 || e.gain < 0 || e.gain > 4 || !(e.pan === 2 || Math.abs(e.pan) <= 1)) throw Error('invalid event');
      last = e.at;
      const block = Math.floor(e.at / Q); count = block === previousBlock ? count + 1 : 1; previousBlock = block;
      if (count > 128) throw Error('onset capacity');
      if (++total > 20000) throw Error('score capacity');
      return freeze({...e});
    }));
  };
  const score = ownRows(b.score, b.length), scenes = {};
  if (!b.scenes || Object.keys(b.scenes).length > 32) throw Error('scene capacity');
  for (const [name, s] of Object.entries(b.scenes)) {
    if (!/^\w{1,32}$/.test(name) || !Number.isSafeInteger(s.length) || s.length < Q || s.length > b.length) throw Error('invalid scene');
    Object.defineProperty(scenes, name, {value: freeze({length: s.length, rows: ownRows(s.rows, s.length)}), enumerable: true});
  }
  let end = 0;
  if (!Array.isArray(b.arrangement) || !b.arrangement.length || b.arrangement.length > 32) throw Error('invalid arrangement');
  const arrangement = b.arrangement.map(row => {
    if (!Object.hasOwn(scenes,row.name) || row.from !== end || row.length !== scenes[row.name].length) throw Error('invalid placement');
    end += row.length; return freeze({...row});
  });
  if (end !== b.length) throw Error('invalid length');
  return freeze({...b, score, scenes: freeze(scenes), arrangement: freeze(arrangement)});
}
export const initial = () => freeze({now: 0, latest: 0, active: null, pending: null});
const result = (state, decision, events=[]) => ({state: freeze(state), decision, events: freeze(events)});
export function position(s) {
  if (!s.active) return {mode: 'waiting', scene: null};
  const a = s.active, local = s.now - a.origin;
  return {mode: a.mode, scene: a.mode === 'score' ? a.bundle.arrangement.find(r => local >= r.from && local < r.from + r.length)?.name ?? 'ended' : a.mode, local};
}
function eventsAt(a, now) {
  const scene = a.mode === 'score' ? {rows: a.bundle.score, length: a.bundle.length} : a.bundle.scenes[a.mode];
  const cycle = a.mode === 'score' ? 0 : Math.floor((now - a.origin) / scene.length);
  const events = [];
  // Two adjacent local cycles can share one audio block when a beat is not Q-aligned.
  for (let n = Math.max(0,cycle); n <= (a.mode === 'score' ? 0 : cycle + 1); n++) {
    const origin = a.origin + n * scene.length, from = now - origin, to = now + Q - origin;
    let lo = 0, hi = scene.rows.length;
    while (lo < hi) {const mid = (lo + hi) >>> 1; if (scene.rows[mid].at < from) lo = mid + 1; else hi = mid;}
    for (let i = lo; i < scene.rows.length && scene.rows[i].at < to; i++) {
      const e = scene.rows[i]; events.push(freeze({...e, at: now, end: Math.ceil(origin + e.end), revision: a.bundle.revision}));
    }
  }
  if (events.length > 256) throw Error('block capacity');
  return events;
}
export function reduce(s, action) {
  if (action.kind === 'tick') {
    if (!s.active) return result(s,'waiting');
    let current = s, decision = 'render';
    if (s.pending && s.now === s.pending.at) {
      current = {...s, active: s.pending.next, pending: null}; decision = 'applied';
    }
    return result({...current, now: s.now + Q}, decision, eventsAt(current.active, s.now));
  }
  if (action.kind === 'cancel') {
    if (!s.pending) return result(s,'not-pending');
    if (s.now >= s.pending.at - Q) return result(s,'deadline');
    return result({...s,pending:null},'cancelled');
  }
  if (s.pending && s.now >= s.pending.at - Q) return result(s,'deadline');
  if (action.kind === 'install') {
    const bundle = action.bundle; // owning validation happens once at admission
    if (bundle.revision <= s.latest) return result(s,'stale');
    if (!s.active) return result({...s,latest:bundle.revision,active:freeze({bundle, mode:'score', origin:0})},'started');
    if (JSON.stringify(bundle.arrangement) !== JSON.stringify(s.active.bundle.arrangement)) return result(s,'layout-change');
    const next = freeze({...(s.pending?.next ?? s.active), bundle});
    return result({...s,latest:bundle.revision,pending:freeze({at:s.pending?.at ?? (Math.floor((s.now + Q)/BAR)+1)*BAR,next})},'reserved');
  }
  if (action.kind === 'game' || action.kind === 'score') {
    if (!s.active) return result(s,'not-ready');
    const at = s.pending?.at ?? (Math.floor((s.now+Q)/BAR)+1)*BAR, bundle = (s.pending?.next ?? s.active).bundle;
    const mode = action.kind === 'game' ? ({calm:'suspension',combat:'confluence'})[action.event] : 'score';
    if (!mode || mode !== 'score' && !Object.hasOwn(bundle.scenes,mode)) return result(s,'unknown-event');
    const row = action.kind === 'score' ? bundle.arrangement.find(r => r.name === action.section) : null;
    if (action.kind === 'score' && !row) return result(s,'unknown-section');
    const offset=action.offsetBeats??0;
    if(!Number.isFinite(offset)||offset<0||action.kind==='score'&&offset*24000>=row.length)return result(s,'invalid-offset');
    return result({...s,pending:freeze({at,next:freeze({bundle,mode,origin:at-(row?.from ?? 0)-offset*24000})})},'reserved');
  }
  return result(s,'unknown-action');
}
