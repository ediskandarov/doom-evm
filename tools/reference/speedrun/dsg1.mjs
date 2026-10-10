// SPDX-License-Identifier: GPL-2.0-only
// Observation diagnostics copied from the accepted gameplay comparison runner.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const sha=data=>createHash('sha256').update(data).digest('hex');
function fields(bytes){
  let pos=0;const rows=[];const one=name=>{assert(pos+4<=bytes.length,`truncated DSG1 at ${name}`);const value=bytes.readInt32BE(pos);rows.push({field:name,value,byte:pos});pos+=4;return value;};
  const group=(prefix,names)=>names.split(' ').forEach(name=>one(prefix+'.'+name));
  group('global','magic leveltime gametic prndindex rndindex gameaction secretexit totalkills totalitems totalsecret gameskill');
  group('player','mo playerstate viewz viewheight deltaviewheight bob health armorpoints armortype');
  for(let i=0;i<6;i++)one(`player.powers[${i}]`);for(let i=0;i<6;i++)one(`player.cards[${i}]`);one('player.backpack');
  for(let i=0;i<4;i++)one(`player.frags[${i}]`);group('player','readyweapon pendingweapon');
  for(let i=0;i<9;i++)one(`player.weaponowned[${i}]`);for(let i=0;i<4;i++){one(`player.ammo[${i}]`);one(`player.maxammo[${i}]`);}
  group('player','attackdown usedown cheats refire killcount itemcount secretcount damagecount bonuscount attacker extralight fixedcolormap colormap didsecret');
  for(let i=0;i<2;i++)group(`player.psprites[${i}]`,'state tics sx sy');
  const thinkers=one('thinkerCount');assert(thinkers>=0&&thinkers<65536);
  const special={2:'sector type topheight speed direction topwait topcountdown',3:'sector type crush direction newspecial texture floordestheight speed',4:'sector type bottomheight topheight speed crush direction tag olddirection',5:'sector speed low high wait count status oldstatus crush tag type',6:'sector count maxlight minlight maxtime mintime',7:'sector count minlight maxlight darktime brighttime',8:'sector minlight maxlight direction',9:'sector count maxlight minlight'};
  for(let i=0;i<thinkers;i++){
    const id=one(`thinkerOrder[${i}]`),base=`thinker[${id}]`,kind=one(base+'.kind');group(base,'callback prev next');
    if(kind===1)group(base+'.actor','x y z angle sprite frame floorz ceilingz radius height momx momy momz type tics state flags health movedir movecount target reactiontime threshold player lastlook tracer subsector snext sprev bnext bprev spawnpoint.x spawnpoint.y spawnpoint.angle spawnpoint.type spawnpoint.options');
    else {assert(special[kind],`unknown DSG1 thinker ${kind}`);group(base+'.special',special[kind]);}
  }
  const sectors=one('sectorCount');for(let i=0;i<sectors;i++)group(`sector[${i}]`,'floorheight ceilingheight floorpic ceilingpic lightlevel special tag soundtraversed soundtarget thinglist specialdata');
  const lines=one('lineCount');for(let i=0;i<lines;i++)group(`line[${i}]`,'flags special tag');
  const sides=one('sideCount');for(let i=0;i<sides;i++)group(`side[${i}]`,'textureoffset rowoffset toptexture bottomtexture midtexture');
  const blocks=one('blockCount');for(let i=0;i<blocks;i++)one(`block[${i}].head`);
  for(let i=0;i<16;i++)if(one(`button[${i}].btimer`))group(`button[${i}]`,'line where btexture');
  for(let i=0;i<30;i++)one(`activeplat[${i}]`);for(let i=0;i<30;i++)one(`activeceiling[${i}]`);
  const textures=one('textureCount');for(let i=0;i<textures;i++)one(`texturetranslation[${i}]`);
  const flats=one('flatCount');for(let i=0;i<flats;i++)one(`flattranslation[${i}]`);
  const head=one('iquehead'),tail=one('iquetail');for(let i=tail;i!==head;i=(i+1)&127)group(`itemqueue[${i}]`,'time x y angle type options');
  assert.equal(pos,bytes.length,'trailing DSG1 words');return rows;
}
function difference(expected,actual){
  if(expected.equals(actual))return null;
  const rows=fields(expected);let offset=0;while(offset<Math.min(expected.length,actual.length)&&expected[offset]===actual[offset])offset++;
  const at=Math.floor(offset/4)*4,record=rows.find(row=>row.byte===at);
  return {field:record?.field??'recordLength',byte:at,native:record?.value??null,evm:at+4<=actual.length?actual.readInt32BE(at):null,nativeBytes:expected.length,evmBytes:actual.length,nativeSha256:sha(expected),evmSha256:sha(actual)};
}

export {fields, difference};
