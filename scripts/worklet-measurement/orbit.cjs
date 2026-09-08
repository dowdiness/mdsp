// The user's original 12-section composition, assembled without changing DSL semantics.
const lead='note("E4 G4 A4").slow(3).gain(0.105)';
const orbit='note("D5 A4 G4 E5").slow(4).jux(rev).gain(0.055)';
const kick='s("bd").gain(0.46)';
const hats='s("hh(5,8)").slow(4).every(3, rev).degradeBy(0.12).gain(0.065)';
const clap='s("cp(2,4,1)").slow(4).gain(0.13)';
const open='s("oh(2,8,1)").slow(4).gain(0.055)';
const chords='chord("Cmaj9 Am7 Fmaj9 G6").slow(48).gain(0.12)';
const bass='note("C2(3,8) A1(3,8,1) F2(3,8) G2(3,8,1)").slow(48).gain(0.25)';
const sections=[
 ['seed',12,[lead,'chord("Cmaj9").slow(12).gain(0.10)']],
 ['second_orbit',12,[lead,orbit,'s("hh(3,8)").slow(4).gain(0.045)']],
 ['ground',24,[lead,orbit,kick,hats,'note("C2(3,8) A1(3,8,1)").slow(24).gain(0.23)','chord("Cmaj9 Am7").slow(24).gain(0.11)']],
 ['daybreak',48,[lead,orbit,chords,bass,kick,clap,hats,open]],
 ['suspension',24,['chord("Fmaj9 Cmaj9").slow(24).gain(0.12)','note("E4 G4 A4").slow(6).jux(rev).gain(0.075)','note("D5 A4 G4 E5").slow(8).gain(0.065)']],
 ['refraction',23,['note("A4 G4 E4").slow(3).gain(0.105)',orbit,'chord("Am7 G6").slow(24).gain(0.11)','note("A1(3,8) G2(3,8,1)").slow(24).gain(0.23)','s("bd(3,8)").slow(4).gain(0.40)',hats,clap]],
 ['one_breath',1,['note("C4").gain(0)']],
 ['confluence',24,[lead,orbit,chords,bass,kick,clap,hats,open,'note("G5(2,8) E5(2,8,1)").slow(12).gain(0.035)']],
 ['alignment',24,['note("E4 G4 A4").slow(4).gain(0.105)',orbit,'chord("Fmaj9 G6 Cmaj9").slow(24).gain(0.13)','note("F2 G2 C2").slow(24).gain(0.25)',kick,clap,hats,open]],
 ['unthread',24,[lead,orbit,'chord("Fmaj9 Cmaj9").slow(24).gain(0.10)','note("F2 C2").slow(24).gain(0.18)',hats]],
 ['remember',12,['note("E4 G4 A4").slow(6).gain(0.075)','chord("Am7").slow(12).gain(0.10)']],
 ['still_light',12,['note("E4 G4 A4").slow(6).gain(0.06)','chord("Cmaj9").slow(12).gain(0.085)']],
];
module.exports={text:'song('+sections.map(([name,n,parts])=>`section("${name}",${n},stack(${parts.join(',')}))`).concat(sections.map(([name],i)=>`part("r${i+1}","${name}")`)).join(',')+')',sections:sections.map(([name,cycles])=>({name,cycles}))};
