// Pure analysis: unavailable or uncalibrated output metrics never mean zero glitches.
function summarize(data) {
  if (data.schema_version !== 1 || !Array.isArray(data.results) || !data.results.length)
    throw new Error('invalid measurement schema');
  const rows = data.results.map(row => {
    let underrun_ms = null, underrun_events = null;
    if (row.before && row.after && row.before.api === row.after.api) {
      const modern = row.after.api === 'playbackStats';
      if (!modern && row.after.api !== 'playoutStats') throw new Error('unknown stats API');
      const duration = modern ? 'underrunDuration' : 'fallbackFramesDuration';
      const events = modern ? 'underrunEvents' : 'fallbackFramesEvents';
      const total = modern ? 'totalDuration' : 'totalFramesDuration';
      for (const key of [duration,events,total]) {
        if (![row.before[key],row.after[key]].every(Number.isFinite) || row.after[key]<row.before[key])
          throw new Error('invalid or non-monotonic stats');
      }
      if (row.after[total] <= row.before[total]) throw new Error('output stats did not advance');
      underrun_ms = (row.after[duration]-row.before[duration])*(modern ? 1000 : 1);
      underrun_events = row.after[events]-row.before[events];
    }
    return {round:row.round,mode:row.mode,underrun_ms,underrun_events,
      preparation_p95_ms:row.preparation.p95_ms,preparation_max_ms:row.preparation.max_ms,
      handler_max_ms:row.handler.max_ms,render_max_ms:row.render.max_ms};
  });
  const controls = rows.filter(r=>r.mode==='positive-control');
  const measuredRounds = new Set(rows.map(r=>r.round));
  for (const round of measuredRounds) {
    const modes = rows.filter(r=>r.round===round).map(r=>r.mode).sort();
    if (modes.join(',') !== 'apply-score,baseline,positive-control,prepare-only')
      throw new Error('incomplete or duplicated comparison round');
  }
  return { calibrated:controls.every(r=>r.underrun_ms>0 && r.underrun_events>0) && rows.every(r=>r.underrun_ms!==null), rows };
}
module.exports = { summarize };
if (require.main === module) {
  const fs = require('node:fs');
  process.stdout.write(JSON.stringify(summarize(JSON.parse(fs.readFileSync(process.argv[2],'utf8'))),null,2)+'\n');
}
