// SPDX-License-Identifier: GPL-2.0-only
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {nativeKey,RawKeyboardInput} from '../../../web/input.mjs';
test('save/load function keys use pinned original doomdef.h numeric symbols',async()=>{
 const header=await readFile('original/DOOM/linuxdoom-1.10/doomdef.h','utf8');
 for(const key of ['F2','F3']){
  const m=header.match(new RegExp('#define KEY_'+key+'\\s+\\(0x([\\da-f]+)\\+0x([\\da-f]+)\\)'));
  assert(m);const original=parseInt(m[1],16)+parseInt(m[2],16);assert.equal(nativeKey(key),original);
  const keyboard=new RawKeyboardInput();keyboard.update(key,true);keyboard.update(key,false);
  assert.deepEqual([...keyboard.packet()],[0,original,1,original]);
 }
 const source=await readFile('src/doom/m_menu.sol','utf8');
 assert(source.includes('ch == 188 || ch == 189'));assert(source.includes('if (ch == 188) M_SaveGame(m)'));
});
