// SPDX-License-Identifier: GPL-2.0-only
static void dispatch_setup(int32_t a[8]){
    setup(a);memset(buttonlist,0,sizeof(buttonlist));memset(switchlist,0,sizeof(switchlist));memset(linespeciallist,0,sizeof(linespeciallist));
    switchlist[0]=0;switchlist[1]=1;switchlist[2]=-1;numswitches=1;
    gameaction=ga_nothing;secretexit=false;totalsecret=0;levelTimer=false;levelTimeCount=0;numlinespecials=0;
    actor.type=a[3]==2?MT_ROCKET:a[3]?MT_POSSESSED:MT_PLAYER;
    if(a[0]==3){sectors[0].special=a[1];for(int i=0;i<3;i++)lines[i].special=48;}
    if(a[0]==4&&a[3])sectors[0].specialdata=&thinkercap;
}
static void dispatch_begin(int32_t a[8]){
    if(a[0]==0)P_CrossSpecialLine(0,a[7],&actor);
    else if(a[0]==1)P_ShootSpecialLine(&actor,lines);
    else if(a[0]==2)return_value=P_UseSpecialLine(&actor,lines,a[7]);
    else if(a[0]==3)P_SpawnSpecials();
    else if(a[0]==4)return_value=EV_DoDonut(lines);
    else abort();
}
int main(void){int32_t a[8];while(scanf("%d",&a[0])==1){for(int i=1;i<8;i++)if(scanf("%d",&a[i])!=1)abort();dispatch_setup(a);dispatch_begin(a);classify();
    for(int i=0;i<8;i++)outputword(a[i]);outputword(a[6]+1);snapshot();overlay();
    for(int tick=0;tick<a[6];tick++){leveltime=tick;classify();P_RunThinkers();P_UpdateSpecials();snapshot();overlay();}
}for(int i=0;i<blockcount;i++)free(blocks[i].pointer);return ferror(stdout)?1:0;}
