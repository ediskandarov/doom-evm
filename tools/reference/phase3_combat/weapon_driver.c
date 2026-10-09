/* SPDX-License-Identifier: GPL-2.0-only */
void P_SetPsprite(player_t*, int, statenum_t);
void A_BFGSpray(mobj_t*);
extern fixed_t swingx, swingy;
void P_CalcSwing(player_t*);
static void word(uint32_t u) { for (int s=24;s>=0;s-=8) putchar((u>>s)&255); }
static void output(int weapon,int ammo,int profile,int hits,int tick) {
    player_t *p=&players[0];
    word(weapon);word(ammo);word(profile);word(hits);word(tick);
    for(int slot=0;slot<NUMPSPRITES;++slot) {
        pspdef_t *psp=&p->psprites[slot];
        word(psp->state?psp->state-states:UINT32_MAX);word(psp->tics);word(psp->sx);word(psp->sy);
    }
    word(p->readyweapon);word(p->pendingweapon);word(p->attackdown);word(p->refire);word(p->extralight);
    for(int i=0;i<NUMAMMO;++i)word(p->ammo[i]);
    word(actor.state?actor.state-states:UINT32_MAX);word(actor.angle);word(actor.flags);word(prndindex);
    word(shotcount);word(linehash);word(aimcount);word(aimhash);word(missilecount);word(missilehash);
    word(noisecount);word(spawncount);word(damagecount);word(damagehash);
    P_CalcSwing(p);word(swingx);word(swingy);
}
int main(void) {
    word(9*2*2*2);word(160);word(33);
    for(int weapon=0;weapon<9;++weapon)for(int ammo=0;ammo<2;++ammo)
    for(int profile=0;profile<2;++profile)for(int hits=0;hits<2;++hits) {
        memset(players,0,sizeof(players));memset(&actor,0,sizeof(actor));memset(&victim,0,sizeof(victim));
        player_t *p=&players[0];p->mo=&actor;p->readyweapon=weapon;p->pendingweapon=wp_nochange;
        p->health=100;p->bob=FRACUNIT;p->playerstate=PST_LIVE;
        for(int i=0;i<NUMWEAPONS;++i)p->weaponowned[i]=true;
        for(int i=0;i<NUMAMMO;++i)p->ammo[i]=ammo?100:0;
        actor.state=&states[S_PLAY];actor.angle=0x12000000;actor.flags=MF_SOLID|MF_SHOOTABLE;
        actor.target=&actor;victim.x=64*FRACUNIT;victim.y=64*FRACUNIT;victim.height=56*FRACUNIT;
        hit=hits;linetarget=NULL;prndindex=17;leveltime=0;
        shotcount=aimcount=missilecount=noisecount=spawncount=damagecount=0;
        linehash=aimhash=missilehash=damagehash=2166136261u;
        P_SetupPsprites(p);
        for(int tick=0;tick<160;++tick) {
            leveltime=tick;p->cmd.buttons=profile==0?BT_ATTACK:((tick%24)<12?BT_ATTACK:0);
            // Strength changes punch damage only; original state transition sequence retained.
            if(tick==70)p->powers[pw_strength]=1;
            if(tick==120){p->health=0;p->playerstate=PST_DEAD;P_DropWeapon(p);}
            P_MovePsprites(p);
            // Actor action profile: BFG spray is separately invoked with original origin identity.
            if(weapon==wp_bfg && tick==100)A_BFGSpray(&actor);
            output(weapon,ammo,profile,hits,tick);
        }
    }
    return ferror(stdout)?1:0;
}
