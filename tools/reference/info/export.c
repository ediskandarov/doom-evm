// SPDX-License-Identifier: GPL-2.0-only
// Original info.c tables exported without invoking any action pointer.
#include <stdint.h>
#include <stdio.h>
#include "info.h"
extern char *sprnames[];
static void word(uint32_t value) { unsigned char b[4]={value>>24,value>>16,value>>8,value}; fwrite(b,1,4,stdout); }
int main(void) {
    word(NUMSPRITES); word(NUMSTATES); word(NUMMOBJTYPES);
    for(unsigned i=0;i<NUMSPRITES;i++) fwrite(sprnames[i],1,4,stdout);
    for(unsigned i=0;i<NUMSTATES;i++) { word(states[i].sprite); word(states[i].frame); }
    for(unsigned i=0;i<NUMMOBJTYPES;i++) {
        word(mobjinfo[i].doomednum); word(mobjinfo[i].spawnstate); word(mobjinfo[i].flags);
        word(mobjinfo[i].radius); word(mobjinfo[i].height);
    }
}
