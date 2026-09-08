// Portable terminal driver for the same decisions used by the AudioWorklet.
import {readFile} from 'node:fs/promises';
import {createInterface} from 'node:readline/promises';
import * as compiler from '../_build/js/release/build/cmd/composition_prepare/composition_prepare.js';
import {prepare} from '../web/composition-prototype/prepare.mjs';
import {initial,reduce,ownBundle,position,BAR} from '../web/composition-prototype/model.mjs';
const doc=JSON.parse(await readFile(new URL('../examples/light-orbit/named.json',import.meta.url)));let revision=1;
let s=reduce(initial(),{kind:'install',bundle:ownBundle(prepare(compiler,doc,revision))}).state;
const terminal=createInterface({input:process.stdin,output:process.stdout});
for(;;){
  console.clear();console.log(JSON.stringify({sample:s.now,...position(s),revision:s.active.bundle.revision,pending:s.pending&&{at:s.pending.at,mode:s.pending.next.mode,revision:s.pending.next.bundle.revision}},null,2));
  const input=await terminal.question('[t] 1小節進む  [calm/combat] ゲーム入力  [edit] orbit音量を変更  [score] alignmentへ戻る  [cancel] 予約取消  [q] 終了\n> ');
  if(input==='q')break;
  if(input==='t'){const end=s.now+BAR;while(s.now<end)s=reduce(s,{kind:'tick'}).state;}
  else if(input==='edit'){doc.patterns.orbit='note("E4 G4 A4").slow(3).gain(0.075)';s=reduce(s,{kind:'install',bundle:ownBundle(prepare(compiler,doc,++revision))}).state;}
  else s=reduce(s,input==='score'?{kind:'score',section:'alignment'}:input==='cancel'?{kind:'cancel'}:{kind:'game',event:input}).state;
}
terminal.close();
