async page=>{
 await page.evaluate(()=>window.composition.start(864000));
 const position=n=>page.waitForFunction(n=>window.composition.latest?.sample>=n,n,{timeout:25000});
 await position(4096);
 await page.selectOption('#section','suspension');await page.fill('#offset','12');await page.click('#score');
 await position(110592);
 const midpoint=await page.evaluate(()=>window.composition.latest);
 if(midpoint.scene!=='suspension'||Math.abs(midpoint.filterHz-600)>1e-5)throw Error('mid-section filter state');
 await page.fill('#cutoff','10000');await page.fill('#filter-beats','4');await page.click('#filter-set');
 await position(147456);await page.fill('#cutoff','1200');await page.fill('#filter-beats','2');await page.click('#filter-set');
 await position(245760);await page.click('#combat');
 await position(311296);
 await page.evaluate(()=>window.composition.edit('orbit','note("E4 G4 A4").slow(3).gain(0.075)'));
 await position(442368);await page.click('#calm');
 await position(589824);await page.selectOption('#section','suspension');await page.fill('#offset','20');await page.click('#score');
 const result=await page.evaluate(async midpoint=>{
   const result=await window.composition.result,pcm=result.pcm;delete result.pcm;result.error=document.getElementById('error').textContent;result.midpoint=midpoint;result.userAgent=navigator.userAgent;result.visibility=document.visibilityState;
   for(const[ext,body]of[['json',JSON.stringify(result)],['pcm',pcm.buffer]]){const r=await fetch('/capture/'+'composition-filter-browser'+'.'+ext,{method:'POST',body});if(!r.ok)throw Error('capture '+r.status);}
   return{stats:result.stats,outputStats:result.outputStats,error:result.error,midpoint:result.midpoint.filterHz};
 },midpoint);
 return result;
}
