async page => {
  await page.reload();await page.click('#start');
  await page.waitForFunction(()=>window.composition.latest?.revision===1,null,{timeout:20000});
  await page.fill('#expression','not a pattern');await page.click('#edit');
  await page.waitForFunction(()=>document.getElementById('error').textContent.length>0,null,{timeout:10000});
  if(await page.locator('#edit').isDisabled())throw Error('failed edit blocked future edits');
  const before=await page.evaluate(()=>window.composition.latest.sample);
  await page.waitForFunction(n=>window.composition.latest.sample>n,before,{timeout:5000});
  const reserved=await page.evaluate(()=>window.composition.command({kind:'game',event:'combat'}));
  const cancelled=await page.evaluate(()=>window.composition.command({kind:'cancel'}));
  if(reserved.decision!=='reserved'||cancelled.decision!=='cancelled')throw Error('cancel failed');
  await page.click('#stop');await page.evaluate(()=>window.composition.result);
  return {actualStartButton:true,invalidEditPreservesPlayback:true,cancelled:true};
}
