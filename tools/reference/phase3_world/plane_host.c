/* SPDX-License-Identifier: GPL-2.0-only */
#include <stdint.h>
#include <stdio.h>
#include "doomdef.h"
#include "p_local.h"
static sector_t sector;
static int obstruction,calls;
static uint32_t hash;
static uint32_t mix(uint32_t h,uint32_t v){return(h^v)*16777619u;}
boolean P_ChangeSector(sector_t*s,boolean crush){
    ++calls;hash=mix(mix(mix(hash,s->floorheight),s->ceilingheight),crush!=0);
    return obstruction==0?false:obstruction==1?true:(calls&1)!=0;
}
static void word(uint32_t u){for(int s=24;s>=0;s-=8)putchar((u>>s)&255);}
