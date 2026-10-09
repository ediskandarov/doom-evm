// SPDX-License-Identifier: GPL-2.0-only
// Pointer-free observation of original gameplay state; no gameplay decisions.
void T_FireFlicker(fireflicker_t *);
static thinker_t *observed[65536];
static int observed_kind[65536], observed_count;
static int thinker_kind(thinker_t *t) {
    actionf_p1 f=t->function.acp1;
    if(f==(actionf_p1)P_MobjThinker) return 1;
    if(f==(actionf_p1)T_VerticalDoor) return 2;
    if(f==(actionf_p1)T_MoveFloor) return 3;
    if(f==(actionf_p1)T_MoveCeiling) return 4;
    if(f==(actionf_p1)T_PlatRaise) return 5;
    if(f==(actionf_p1)T_LightFlash) return 6;
    if(f==(actionf_p1)T_StrobeFlash) return 7;
    if(f==(actionf_p1)T_Glow) return 8;
    if(f==(actionf_p1)T_FireFlicker) return 9;
    if(!f || t->function.acv==(actionf_v)-1) return 0;
    I_Error("Unknown thinker callback");return 0;
}
static int identity(void *p) {
    if(!p) return 0;
    if(p==&thinkercap) return -1;
    for(int i=observed_count-1;i>=0;i--) if(observed[i]==p) return i+1;
    I_Error("Unobserved thinker reference");return 0;
}
void OracleAddThinker(void *p) {
    if(observed_count==65536) I_Error("Observation capacity");
    observed[observed_count]=p;observed_kind[observed_count]=0;observed_count++;
}
void OracleRemoveThinker(void *p) {
    int id=identity(p),kind=thinker_kind(p);
    if(kind) observed_kind[id-1]=kind;
}
static int sector_id(sector_t *s) { return s ? (int)(s-sectors):-1; }
static void observe_actor(FILE *f,mobj_t *m) {
#define W(field) word(f,m->field)
    W(x);W(y);W(z);W(angle);W(sprite);W(frame);W(floorz);W(ceilingz);W(radius);W(height);
    W(momx);W(momy);W(momz);W(type);W(tics);word(f,m->state ? m->state-states:-1);W(flags);W(health);
    W(movedir);W(movecount);word(f,identity(m->target));W(reactiontime);W(threshold);
    word(f,m->player ? m->player-players:-1);W(lastlook);word(f,identity(m->tracer));
    word(f,m->subsector ? m->subsector-subsectors:-1);
    word(f,identity(m->snext));word(f,identity(m->sprev));word(f,identity(m->bnext));word(f,identity(m->bprev));
    word(f,m->spawnpoint.x);word(f,m->spawnpoint.y);word(f,m->spawnpoint.angle);word(f,m->spawnpoint.type);word(f,m->spawnpoint.options);
#undef W
}
static void observe_special(FILE *f,thinker_t *t,int kind) {
#define FIELD(type,field) word(f,((type*)t)->field)
#define SEC(type) word(f,sector_id(((type*)t)->sector))
    switch(kind) {
      case 2: SEC(vldoor_t);FIELD(vldoor_t,type);FIELD(vldoor_t,topheight);FIELD(vldoor_t,speed);FIELD(vldoor_t,direction);FIELD(vldoor_t,topwait);word(f,((vldoor_t*)t)->direction==0 || ((vldoor_t*)t)->direction==2 ? ((vldoor_t*)t)->topcountdown:INT32_MIN);break;
      case 3: SEC(floormove_t);FIELD(floormove_t,type);FIELD(floormove_t,crush);FIELD(floormove_t,direction);word(f,((floormove_t*)t)->type==donutRaise || ((floormove_t*)t)->type==lowerAndChange ? ((floormove_t*)t)->newspecial:INT32_MIN);word(f,((floormove_t*)t)->type==donutRaise || ((floormove_t*)t)->type==lowerAndChange ? ((floormove_t*)t)->texture:INT32_MIN);FIELD(floormove_t,floordestheight);FIELD(floormove_t,speed);break;
      case 4: SEC(ceiling_t);FIELD(ceiling_t,type);FIELD(ceiling_t,bottomheight);FIELD(ceiling_t,topheight);FIELD(ceiling_t,speed);FIELD(ceiling_t,crush);FIELD(ceiling_t,direction);FIELD(ceiling_t,tag);word(f,((ceiling_t*)t)->direction==0 ? ((ceiling_t*)t)->olddirection:INT32_MIN);break;
      case 5: SEC(plat_t);FIELD(plat_t,speed);FIELD(plat_t,low);FIELD(plat_t,high);FIELD(plat_t,wait);word(f,((plat_t*)t)->status==waiting || (((plat_t*)t)->status==in_stasis && ((plat_t*)t)->oldstatus==waiting) ? ((plat_t*)t)->count:INT32_MIN);FIELD(plat_t,status);word(f,((plat_t*)t)->status==in_stasis ? ((plat_t*)t)->oldstatus:INT32_MIN);FIELD(plat_t,crush);FIELD(plat_t,tag);FIELD(plat_t,type);break;
      case 6: SEC(lightflash_t);FIELD(lightflash_t,count);FIELD(lightflash_t,maxlight);FIELD(lightflash_t,minlight);FIELD(lightflash_t,maxtime);FIELD(lightflash_t,mintime);break;
      case 7: SEC(strobe_t);FIELD(strobe_t,count);FIELD(strobe_t,minlight);FIELD(strobe_t,maxlight);FIELD(strobe_t,darktime);FIELD(strobe_t,brighttime);break;
      case 8: SEC(glow_t);FIELD(glow_t,minlight);FIELD(glow_t,maxlight);FIELD(glow_t,direction);break;
      case 9: SEC(fireflicker_t);FIELD(fireflicker_t,count);FIELD(fireflicker_t,maxlight);FIELD(fireflicker_t,minlight);break;
      default:I_Error("Unknown observed kind");
    }
#undef FIELD
#undef SEC
}
static void observe_player(FILE *f,player_t *p) {
#define W(field) word(f,p->field)
    word(f,identity(p->mo));W(playerstate);
    W(viewz);W(viewheight);W(deltaviewheight);W(bob);W(health);W(armorpoints);W(armortype);
    for(int i=0;i<NUMPOWERS;i++) word(f,p->powers[i]);for(int i=0;i<NUMCARDS;i++) word(f,p->cards[i]);W(backpack);
    for(int i=0;i<MAXPLAYERS;i++) word(f,p->frags[i]);W(readyweapon);W(pendingweapon);
    for(int i=0;i<NUMWEAPONS;i++) word(f,p->weaponowned[i]);for(int i=0;i<NUMAMMO;i++) {word(f,p->ammo[i]);word(f,p->maxammo[i]);}
    W(attackdown);W(usedown);W(cheats);W(refire);W(killcount);W(itemcount);W(secretcount);W(damagecount);W(bonuscount);
    word(f,identity(p->attacker));W(extralight);W(fixedcolormap);W(colormap);W(didsecret);
    for(int i=0;i<NUMPSPRITES;i++) {pspdef_t *ps=p->psprites+i;word(f,ps->state ? ps->state-states:-1);word(f,ps->tics);word(f,ps->sx);word(f,ps->sy);}
#undef W
}
extern int numtextures,numflats;
static void observe_world(FILE *f) {
    word(f,0x44534731);word(f,leveltime);word(f,gametic);word(f,prndindex);word(f,rndindex);word(f,gameaction);word(f,secretexit);
    word(f,totalkills);word(f,totalitems);word(f,totalsecret);word(f,gameskill);
    observe_player(f,players);
    int count=0;for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next) count++;word(f,count);
    for(thinker_t *t=thinkercap.next;t!=&thinkercap;t=t->next) {
        int id=identity(t),kind=thinker_kind(t);if(kind) observed_kind[id-1]=kind;else kind=observed_kind[id-1];
        if(!kind) I_Error("Unclassified thinker");
        word(f,id);word(f,kind);word(f,t->function.acv==(actionf_v)-1 ? -1:(!t->function.acv?0:1));
        word(f,identity(t->prev));word(f,identity(t->next));
        if(kind==1) observe_actor(f,(mobj_t*)t);else observe_special(f,t,kind);
    }
    word(f,numsectors);
    for(int i=0;i<numsectors;i++) {sector_t *s=sectors+i;
        word(f,s->floorheight);word(f,s->ceilingheight);word(f,s->floorpic);word(f,s->ceilingpic);word(f,s->lightlevel);word(f,s->special);word(f,s->tag);
        word(f,s->soundtraversed);word(f,identity(s->soundtarget));word(f,identity(s->thinglist));word(f,identity(s->specialdata));
    }
    word(f,numlines);for(int i=0;i<numlines;i++) {word(f,lines[i].flags);word(f,lines[i].special);word(f,lines[i].tag);}
    word(f,numsides);for(int i=0;i<numsides;i++) {side_t *s=sides+i;word(f,s->textureoffset);word(f,s->rowoffset);word(f,s->toptexture);word(f,s->bottomtexture);word(f,s->midtexture);}
    word(f,bmapwidth*bmapheight);for(int i=0;i<bmapwidth*bmapheight;i++) word(f,identity(blocklinks[i]));
    for(int i=0;i<MAXBUTTONS;i++) {button_t *b=buttonlist+i;word(f,b->btimer);if(b->btimer) {word(f,b->line-lines);word(f,b->where);word(f,b->btexture);}}
    for(int i=0;i<MAXPLATS;i++) word(f,identity(activeplats[i]));for(int i=0;i<MAXCEILINGS;i++) word(f,identity(activeceilings[i]));
    word(f,numtextures);for(int i=0;i<numtextures;i++) word(f,texturetranslation[i]);word(f,numflats);for(int i=0;i<numflats;i++) word(f,flattranslation[i]);
    word(f,iquehead);word(f,iquetail);
    // Logical queue only: untouched slots are not initialized by the original game.
    for(int i=iquetail;i!=iquehead;i=(i+1)&(ITEMQUESIZE-1)) {mapthing_t *m=itemrespawnque+i;word(f,itemrespawntime[i]);word(f,m->x);word(f,m->y);word(f,m->angle);word(f,m->type);word(f,m->options);}
}
