// SPDX-License-Identifier: GPL-2.0-only
// Additional pointer-free startup observations; no setup decisions.
static void episode_collision(FILE *f) {
    word(f,bmaporgx);word(f,bmaporgy);word(f,bmapwidth);word(f,bmapheight);
    int base=W_GetNumForName(episode_map_name);
    int count=W_LumpLength(base+ML_BLOCKMAP)/2;
    word(f,count);for(int i=0;i<count;i++)word(f,blockmaplump[i]);
    int rejectsize=W_LumpLength(base+ML_REJECT);
    word(f,rejectsize);if(fwrite(rejectmatrix,1,(size_t)rejectsize,f)!=(size_t)rejectsize)I_Error("reject write");
    word(f,numsectors);
    for(int i=0;i<numsectors;i++) {
        sector_t *s=sectors+i;word(f,s->linecount);
        for(int j=0;j<s->linecount;j++)word(f,s->lines[j]-lines);
        word(f,s->soundorg.x);word(f,s->soundorg.y);
        for(int j=0;j<4;j++)word(f,s->blockbox[j]);
    }
    word(f,numlinespecials);for(int i=0;i<numlinespecials;i++)word(f,linespeciallist[i]-lines);
    for(int i=0;i<MAXPLAYERS;i++) {
        mapthing_t *m=playerstarts+i;
        word(f,m->x);word(f,m->y);word(f,m->angle);word(f,m->type);word(f,m->options);
    }
    word(f,deathmatch_p-deathmatchstarts);
    for(mapthing_t *m=deathmatchstarts;m<deathmatch_p;m++) {
        word(f,m->x);word(f,m->y);word(f,m->angle);word(f,m->type);word(f,m->options);
    }
}
static void episode_flow(FILE *f) {
    word(f,gameepisode);word(f,gamemap);word(f,gamemode);word(f,gamestate);word(f,gameaction);word(f,gameskill);
    word(f,paused);word(f,menuactive);word(f,netgame);word(f,deathmatch);word(f,consoleplayer);word(f,displayplayer);
    word(f,respawnmonsters);word(f,nomonsters);word(f,fastparm);word(f,levelstarttic);
    word(f,usergame);word(f,viewactive);word(f,automapactive);word(f,wipegamestate);
    word(f,wminfo.maxfrags);word(f,wminfo.partime);
}
static void episode_difficulty(FILE *f) {
    for(int i=S_SARG_RUN1;i<=S_SARG_PAIN2;i++)word(f,states[i].tics);
    word(f,mobjinfo[MT_BRUISERSHOT].speed);word(f,mobjinfo[MT_HEADSHOT].speed);word(f,mobjinfo[MT_TROOPSHOT].speed);
}
