async page=>{
 await page.reload();await page.evaluate(()=>window.composition.start());
 const replies=await page.evaluate(()=>Promise.all([
   window.composition.edit('orbit','note("E4 G4 A4").slow(3).gain(0.08)'),
   window.composition.edit('kick','s("bd").gain(0.3)')
 ]));
 if(replies[0].decision!=='superseded'||replies[1].decision!=='reserved')throw Error('latest edit not selected');
 await page.waitForFunction(()=>window.composition.latest?.revision===3,null,{timeout:10000});
 const cancelled=await page.evaluate(async()=>{
   const pending=window.composition.edit('orbit','note("E4 G4 A4").slow(3).gain(0.09)');
   await window.composition.cancel();return pending;
 });
 if(cancelled.decision!=='superseded')throw Error('compilation cancel failed');
 await page.waitForTimeout(2000);
 if(await page.evaluate(()=>window.composition.latest.revision)!==3)throw Error('retired edit resurrected');
 await page.click('#stop');
 return await page.evaluate(async({replies,cancelled})=>{
   const r=await window.composition.result;
   const output={replies,cancelled,preparations:r.log.filter(e=>e.kind==='preparation'),stats:r.stats};
   if(output.preparations.some(e=>e.revision===2||e.revision===4))throw Error('stale preparation published');
   await fetch('/capture/'+(location.search.includes('definition')?'composition-definition-race':'composition-race')+'.json',{method:'POST',body:JSON.stringify(output)});return output;
 },{replies,cancelled});
}
