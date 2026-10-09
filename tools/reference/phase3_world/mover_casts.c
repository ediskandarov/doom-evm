/* SPDX-License-Identifier: GPL-2.0-only
 * Independent audit of original active-floor/ceiling/plat door reinterpretation.
 * Not consumed by the currently frozen world fixtures. */
int main(int argc,char **argv){
    (void)argv;int32_t a[8]={2,1,0,0,0,0,0,0};
    if(argc>1){
        setup(a);lines[0].special=1;P_SpawnFireFlicker(&sectors[0]);
        sectors[0].specialdata=blocks[0].pointer;EV_VerticalDoor(&lines[0],&actor);return 0;
    }
    printf("{\"offsets\":{\"doorDirection\":%zu,\"floorNewspecial\":%zu,\"floorTexture\":%zu,\"ceilingSpeed\":%zu,\"platCount\":%zu,\"fireFlickerSize\":%zu},\"cases\":[",offsetof(vldoor_t,direction),offsetof(floormove_t,newspecial),offsetof(floormove_t,texture),offsetof(ceiling_t,speed),offsetof(plat_t,count),sizeof(fireflicker_t));
    int printed=0;
    for(int kind=4;kind<=5;++kind)for(int player=0;player<2;++player)for(int before=-1;before<=7;before+=8){
        setup(a);lines[0].special=1;actor.player=player?&players[0]:NULL;int *field;
        if(kind==4){ceiling_t*p=Z_Malloc(sizeof(*p),PU_LEVSPEC,0);P_AddThinker(&p->thinker);p->sector=&sectors[0];field=&p->speed;sectors[0].specialdata=p;}
        else{plat_t*p=Z_Malloc(sizeof(*p),PU_LEVSPEC,0);P_AddThinker(&p->thinker);p->sector=&sectors[0];field=&p->count;sectors[0].specialdata=p;}
        *field=before;EV_VerticalDoor(&lines[0],&actor);
        printf("%s{\"kind\":%d,\"player\":%s,\"before\":%d,\"after\":%d}",printed++?",":"",kind,player?"true":"false",before,*field);
    }
    printf("]}\n");for(int i=0;i<blockcount;++i)free(blocks[i].pointer);return 0;
}
