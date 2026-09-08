const { test } = require('node:test');
const assert = require('node:assert/strict');
const { summarize } = require('./analyze.cjs');
function fixture(api='playoutStats') {
  const modern=api==='playbackStats';
  const keys=modern ? ['underrunDuration','underrunEvents','totalDuration'] : ['fallbackFramesDuration','fallbackFramesEvents','totalFramesDuration'];
  return {schema_version:1,results:['baseline','prepare-only','apply-score','positive-control'].map(mode=>({
    round:0,mode,preparation:{},handler:{},render:{},before:{api,[keys[0]]:0,[keys[1]]:0,[keys[2]]:1},
    after:{api,[keys[0]]:mode==='positive-control' ? (modern ? .1 : 100) : 0,[keys[1]]:mode==='positive-control' ? 1 : 0,[keys[2]]:10},
  }))};
}
test('normalizes both API duration units and requires a positive control',()=>{
  for (const api of ['playoutStats','playbackStats']) {
    const result=summarize(fixture(api));
    assert.equal(result.calibrated,true);
    assert.equal(result.rows[3].underrun_ms,100);
  }
});
test('unavailable stats are not evidence of zero underruns',()=>{
  const input=fixture(); input.results[0].before=input.results[0].after=null;
  const result=summarize(input);
  assert.equal(result.calibrated,false); assert.equal(result.rows[0].underrun_ms,null);
});
test('a detector that misses the known stall is not calibrated',()=>{
  const input=fixture(); input.results[3].after.fallbackFramesDuration=0;
  assert.equal(summarize(input).calibrated,false);
});
test('rejects incomplete, reset or frozen statistics',()=>{
  const input=fixture(); input.results.pop(); assert.throws(()=>summarize(input));
  const reset=fixture(); reset.results[0].after.totalFramesDuration=0; assert.throws(()=>summarize(reset));
  const frozen=fixture(); frozen.results[0].after.totalFramesDuration=1; assert.throws(()=>summarize(frozen));
});
