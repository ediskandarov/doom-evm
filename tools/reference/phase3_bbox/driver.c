// SPDX-License-Identifier: GPL-2.0-only
#include <stdio.h>
#include <stdint.h>
#include "m_bbox.h"
_Static_assert(sizeof(fixed_t)==4 && sizeof(int)==4,"pinned integer profile");
static void word(int32_t value){uint32_t v=(uint32_t)value;unsigned char b[]={v>>24,v>>16,v>>8,v};fwrite(b,1,4,stdout);}
static void bounds(fixed_t *box){for(int i=0;i<4;i++)word(box[i]);}
int main(void){int count;while(scanf("%d",&count)==1){if(count<0||count>4096)return 2;fixed_t box[4];M_ClearBox(box);word(count);bounds(box);for(int i=0;i<count;i++){int x,y;if(scanf("%d %d",&x,&y)!=2)return 3;M_AddToBox(box,x,y);word(x);word(y);bounds(box);}}return feof(stdin)?0:4;}
