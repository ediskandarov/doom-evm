/* SPDX-License-Identifier: GPL-2.0-only */
int main(void){
    int32_t a[8]={3,0,0,0,0,0,0,0};
    printf("{\"closeDoorUninitialized\":[");
    for(int fill=0;fill<2;++fill){
        setup(a);allocation_fill=fill?0xa5:0;P_SpawnDoorCloseIn30(&sectors[0]);
        vldoor_t*p=(vldoor_t*)blocks[0].pointer;
        printf("%s{\"fill\":%d,\"topheight\":%u,\"topwait\":%u}",fill?",":"",allocation_fill,(uint32_t)p->topheight,(uint32_t)p->topwait);
    }
    printf("],\"stairUninitialized\":[");
    for(int fill=0;fill<2;++fill){
        setup(a);allocation_fill=fill?0xa5:0;EV_BuildStairs(&lines[0],build8);
        floormove_t*p=(floormove_t*)blocks[0].pointer;
        printf("%s{\"fill\":%d,\"type\":%u,\"crush\":%u}",fill?",":"",allocation_fill,(uint32_t)p->type,(uint32_t)p->crush);
    }
    printf("],\"incompatibleDoorPlat\":{\"doorDirectionOffset\":%zu,\"platCountOffset\":%zu,\"cases\":[",offsetof(vldoor_t,direction),offsetof(plat_t,count));
    for(int i=0;i<4;++i){
        setup(a);allocation_fill=0;lines[0].special=1;actor.player=i&1?NULL:&players[0];
        plat_t*p=Z_Malloc(sizeof(*p),PU_LEVSPEC,0);P_AddThinker(&p->thinker);p->thinker.function.acp1=(actionf_p1)T_PlatRaise;
        p->sector=&sectors[0];p->count=i<2?7:-1;p->status=waiting;sectors[0].specialdata=p;
        int before=p->count;EV_VerticalDoor(&lines[0],&actor);
        printf("%s{\"player\":%s,\"countBefore\":%d,\"countAfter\":%d}",i?",":"",actor.player?"true":"false",before,p->count);
    }
    printf("]},\"platErrors\":[");
    setup(a);allocation_fill=0;expect_error=1;
    if(!setjmp(error_escape)){
        for(int i=0;i<31;++i){plat_t*p=Z_Malloc(sizeof(*p),PU_LEVSPEC,0);P_AddThinker(&p->thinker);
            p->sector=&sectors[0];P_AddActivePlat(p);}abort();
    }
    printf("\"%s\",",last_error);
    setup(a);allocation_fill=0;
    if(!setjmp(error_escape)){plat_t*p=Z_Malloc(sizeof(*p),PU_LEVSPEC,0);P_RemoveActivePlat(p);abort();}
    printf("\"%s\"],\"genericDonutDefinedNoAllocation\":[",last_error);
    setup(a);lines[0].tag=999;printf("%d,",EV_DoFloor(&lines[0],donutRaise));
    setup(a);sectors[0].specialdata=&actor;sectors[1].specialdata=&actor;
    printf("%d]}\n",EV_DoFloor(&lines[0],donutRaise));
    for(int i=0;i<blockcount;++i)free(blocks[i].pointer);return 0;
}
