/* SPDX-License-Identifier: GPL-2.0-only */
static void begin(int32_t a[8]){
    switch(a[0]){
      case 1:return_value=EV_DoDoor(&lines[0],a[1]);break;
      case 2:EV_VerticalDoor(&lines[0],&actor);break;
      case 3:if(a[1])P_SpawnDoorRaiseIn5Mins(&sectors[0],0);else P_SpawnDoorCloseIn30(&sectors[0]);break;
      case 4:return_value=EV_DoFloor(&lines[0],a[1]);break;
      case 5:return_value=EV_DoCeiling(&lines[0],a[1]);break;
      case 6:return_value=EV_DoPlat(&lines[0],a[1],a[4]);break;
      case 7:
        switch(a[1]){
          case 0:P_SpawnFireFlicker(&sectors[0]);break;
          case 1:P_SpawnLightFlash(&sectors[0]);break;
          case 2:P_SpawnStrobeFlash(&sectors[0],a[4],a[3]);break;
          case 3:P_SpawnGlowingLight(&sectors[0]);break;
          case 4:EV_StartLightStrobing(&lines[0]);break;
          case 5:EV_TurnTagLightsOff(&lines[0]);break;
          case 6:EV_LightTurnOn(&lines[0],0);break;
          case 7:EV_LightTurnOn(&lines[0],255);break;
          default:abort();
        }break;
      case 8:return_value=EV_BuildStairs(&lines[0],a[1]);break;
      case 9:{
        floormove_t*f=Z_Malloc(sizeof(*f),PU_LEVSPEC,0);P_AddThinker(&f->thinker);
        f->thinker.function.acp1=(actionf_p1)T_MoveFloor;f->sector=&sectors[0];sectors[0].specialdata=f;
        f->type=a[1];f->direction=a[3]?-1:1;f->speed=FRACUNIT;f->floordestheight=a[3]?-8*FRACUNIT:8*FRACUNIT;
        f->texture=7;f->newspecial=11;f->crush=a[4]!=0;break;
      }
      case 10:
        for(int i=0;i<31;++i){ceiling_t*p=Z_Malloc(sizeof(*p),PU_LEVSPEC,0);P_AddThinker(&p->thinker);
            p->thinker.function.acp1=(actionf_p1)T_MoveCeiling;p->sector=&sectors[0];p->tag=7;
            P_AddActiveCeiling(p);}
        P_RemoveActiveCeiling((ceiling_t*)blocks[30].pointer);break;
      case 11:return_value=EV_DoLockedDoor(&lines[0],a[7],&actor);break;
      default:abort();
    }
}
int main(void){
    int32_t a[8];
    while(scanf("%d",&a[0])==1){
        for(int i=1;i<8;++i)if(scanf("%d",&a[i])!=1)abort();
        setup(a);begin(a);classify();
        for(int i=0;i<8;++i)outputword(a[i]);outputword(a[6]+1);
        snapshot();
        for(int tick=0;tick<a[6];++tick){
            leveltime=tick;
            if(a[0]==2&&lines[0].special&&(tick==20||tick==40))EV_VerticalDoor(&lines[0],&actor);
            if(a[0]==5&&tick==10)return_value=EV_CeilingCrushStop(&lines[0]);
            if(a[0]==5&&tick==30)P_ActivateInStasisCeiling(&lines[0]);
            if(a[0]==6&&tick==10)EV_StopPlat(&lines[0]);
            if(a[0]==6&&tick==30)P_ActivateInStasis(lines[0].tag);
            if(a[0]==5&&tick==50)return_value=EV_DoCeiling(&lines[0],a[1]);
            if(a[0]==6&&tick==50)return_value=EV_DoPlat(&lines[0],a[1],a[4]);
            classify();P_RunThinkers();snapshot();
        }
    }
    for(int i=0;i<blockcount;++i)free(blocks[i].pointer);
    return ferror(stdout)?1:0;
}
