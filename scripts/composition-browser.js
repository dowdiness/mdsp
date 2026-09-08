async page => {
  await page.evaluate(()=>window.composition.start(864000));
  const position=async n=>page.waitForFunction(n=>window.composition.latest?.sample>=n,n,{timeout:30000});
  await position(4096);
  await page.selectOption('#section','confluence');await page.click('#score');
  await page.waitForFunction(()=>window.composition.latest?.scene==='confluence',null,{timeout:10000});
  if(page.url().includes('definition'))await position(168000);
  await page.fill('#expression','note("E4 G4 A4").slow(3).gain(0.075)');await page.click('#edit');
  await page.waitForFunction(()=>window.composition.latest?.revision===2,null,{timeout:15000});
  await page.click('#calm');
  await page.waitForFunction(()=>window.composition.latest?.mode==='suspension',null,{timeout:10000});
  await position(480000);await page.click('#combat');
  await page.waitForFunction(()=>window.composition.latest?.mode==='confluence',null,{timeout:10000});
  await position(655360);await page.selectOption('#section','alignment');await page.click('#score');
  return await page.evaluate(async()=>{
    const result=await window.composition.result,pcm=result.pcm;delete result.pcm;
    result.error=document.getElementById('error').textContent;
    for(const [ext,body] of [['json',JSON.stringify(result)],['pcm',pcm.buffer]]){
      const res=await fetch('/capture/'+(location.search.includes('definition')?'composition-definition-browser':location.search.includes('incremental')?'composition-incremental-browser':'composition-browser')+'.'+ext,{method:'POST',body});if(!res.ok)throw Error('capture '+res.status);
    }
    return {frames:result.frames,stats:result.stats,events:result.events.length,log:result.log,error:result.error};
  });
}
