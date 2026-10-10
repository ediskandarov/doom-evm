static cheatseq_t *all[16];
static int sizes[16];
static void word(uint32_t v){putchar(v>>24);putchar(v>>16);putchar(v>>8);putchar(v);}
static void snapshot(void){
    word(plyr->health);word(plyr->armorpoints);word(plyr->armortype);word(plyr->cheats);
    word(actors[consoleplayer].health);word(actors[consoleplayer].flags);
    for(int i=0;i<6;i++)word(plyr->powers[i]);
    for(int i=0;i<6;i++)word(plyr->cards[i]);
    for(int i=0;i<9;i++)word(plyr->weaponowned[i]);
    for(int i=0;i<4;i++)word(plyr->ammo[i]);
    for(int i=0;i<4;i++)word(plyr->maxammo[i]);
    word(gameaction);word(d_skill);word(d_episode);word(d_map);word(cheating);
    int len=plyr->message?strlen(plyr->message):0;word(len);if(len)fwrite(plyr->message,1,len,stdout);
    for(int i=0;i<16;i++){
        cheatseq_t *s=all[i];int n=sizes[i];
        word(s->p?(uint32_t)(s->p-s->sequence):0);word(n);fwrite(s->sequence,1,n,stdout);
    }
}
int main(void){
    all[0]=&cheat_god;all[1]=&cheat_ammonokey;all[2]=&cheat_ammo;all[3]=&cheat_noclip;all[4]=&cheat_commercial_noclip;
    for(int i=0;i<7;i++)all[5+i]=&cheat_powerup[i];
    all[12]=&cheat_choppers;all[13]=&cheat_mypos;all[14]=&cheat_clev;all[15]=&cheat_amap;
    for(int i=0;i<16;i++){while(all[i]->sequence[sizes[i]]!=255)sizes[i]++;sizes[i]++;}
    int op;
    while(scanf("%d",&op)==1){
        if(op==0){
            int mode,net,skill,cp,mo,health,mh,power;
            if(scanf("%d%d%d%d%d%d%d%d",&mode,&net,&skill,&cp,&mo,&health,&mh,&power)!=8)abort();
            netgame=net;gamemode=mode;gameskill=skill;consoleplayer=cp;
            memset(players,0,sizeof(players));memset(actors,0,sizeof(actors));
            plyr=&players[cp];plyr->health=health;plyr->mo=mo?&actors[cp]:NULL;
            actors[cp].health=mh;actors[cp].angle=0xabcdef01;actors[cp].x=-65536;actors[cp].y=0x12345678;
            plyr->weaponowned[0]=plyr->weaponowned[1]=1;
            for(int i=0;i<6;i++){plyr->powers[i]=power;plyr->cards[i]=(i%2)==0;}
            for(int i=0;i<4;i++){plyr->ammo[i]=i+1;plyr->maxammo[i]=(int[]){400,100,600,100}[i];}
            gameaction=d_skill=d_episode=d_map=cheating=0;
            for(int i=0;i<16;i++)all[i]->p=NULL;
            cheat_clev_seq[7]=cheat_clev_seq[8]=0;
        }else if(op==1){
            int type,key,active,dm;if(scanf("%d%d%d%d",&type,&key,&active,&dm)!=4)abort();
            deathmatch=dm;event_t ev={type,key,0,0};
            /* Original G_Responder calls ST before AM. Observing only cheat effects. */
            ST_Responder(&ev);
            if(active&&type==ev_keydown){
                AM_Cheat(&ev);
            }
            snapshot();
        }else abort();
    }
}
