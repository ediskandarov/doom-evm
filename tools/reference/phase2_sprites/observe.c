static mobj_t *spawned_objects[4096];
static int spawned_count;
extern vissprite_t vsprsortedhead;
static int thing_index(mobj_t *p) {
    if(!p)return -1;
    for(int i=0;i<spawned_count;i++)if(spawned_objects[i]==p)return i;
    I_Error("unregistered thing");return -2;
}
static void sprite_outputs(const char *directory) {
    FILE *f=output(directory,"definitions.bin");word(f,numsprites);
    for(int i=0;i<numsprites;i++) {
        word(f,sprites[i].numframes);
        for(int j=0;j<sprites[i].numframes;j++) {
            spriteframe_t *s=&sprites[i].spriteframes[j];word(f,s->rotate);
            for(int r=0;r<8;r++){word(f,s->lump[r]);word(f,s->flip[r]);}
        }
    }
    fclose(f);f=output(directory,"things.bin");word(f,spawned_count);
    for(int i=0;i<spawned_count;i++) {
        mobj_t *o=spawned_objects[i];word(f,o->x);word(f,o->y);word(f,o->z);word(f,o->angle);
        word(f,o->sprite);word(f,o->frame);word(f,o->flags);word(f,o->subsector->sector-sectors);word(f,thing_index(o->snext));
    }
    word(f,numsectors);for(int i=0;i<numsectors;i++)word(f,thing_index(sectors[i].thinglist));fclose(f);
    f=output(directory,"vissprites.bin");word(f,vissprite_p-vissprites);
    for(vissprite_t *v=vissprites;v<vissprite_p;v++) {
        word(f,v->x1);word(f,v->x2);word(f,v->gx);word(f,v->gy);word(f,v->gz);word(f,v->gzt);
        word(f,v->startfrac);word(f,v->scale);word(f,v->xiscale);word(f,v->texturemid);word(f,v->patch);
        word(f,v->colormap?(v->colormap-colormaps)/256:-1);word(f,v->mobjflags);
    }
    fclose(f);R_SortVisSprites();f=output(directory,"sorted.bin");word(f,vissprite_p-vissprites);
    if(vissprite_p>vissprites)for(vissprite_t *v=vsprsortedhead.next;v!=&vsprsortedhead;v=v->next)word(f,v-vissprites);
    fclose(f);
}
extern lighttable_t **spritelights;
extern vissprite_t overflowsprite;
extern int fuzzpos;
static void vis_words(FILE *f,vissprite_t *v) {
    word(f,v->x1);word(f,v->x2);word(f,v->gx);word(f,v->gy);word(f,v->gz);word(f,v->gzt);
    word(f,v->startfrac);word(f,v->scale);word(f,v->xiscale);word(f,v->texturemid);word(f,v->patch);
    word(f,v->colormap?(v->colormap-colormaps)/256:-1);word(f,v->mobjflags);
}
static void sprite_edges(const char *directory) {
    spriteframe_t frame={0}; sprites[0].numframes=1;sprites[0].spriteframes=&frame;
    spritewidth[0]=8*FRACUNIT;spriteoffset[0]=0;spritetopoffset[0]=8*FRACUNIT;
    viewx=viewy=viewz=0;viewcos=FRACUNIT;viewsin=0;viewwidth=320;viewheight=200;
    centerxfrac=160*FRACUNIT;centeryfrac=100*FRACUNIT;projection=160*FRACUNIT;detailshift=0;
    fixedcolormap=NULL;spritelights=scalelight[7];
    for(int i=0;i<48;i++)spritelights[i]=colormaps+(i%32)*256;
    FILE *f=output(directory,"projection-edges.bin");word(f,12);
    for(int i=0;i<12;i++) {
        mobj_t t={0};t.x=160*FRACUNIT;t.sprite=0;
        fixedcolormap=NULL;frame.flip[0]=0;
        if(i==1)t.x=3*FRACUNIT;
        if(i==2)t.y=-160*FRACUNIT; // preserves x1==viewwidth empty vissprite
        if(i==3)t.y=170*FRACUNIT;
        if(i==4)t.y=159*FRACUNIT;
        if(i==5)frame.flip[0]=1;
        if(i==6)t.flags=MF_SHADOW;
        if(i==7){t.frame=FF_FULLBRIGHT;fixedcolormap=colormaps+256*3;}
        if(i==8)t.frame=FF_FULLBRIGHT;
        if(i==9)t.flags=MF_TRANSLATION;
        if(i==10){t.flags=MF_SHADOW;t.frame=FF_FULLBRIGHT;fixedcolormap=colormaps+256*3;}
        if(i==11)t.x=4*FRACUNIT;
        R_ClearSprites();R_ProjectSprite(&t);word(f,vissprite_p-vissprites);
        if(vissprite_p>vissprites)vis_words(f,vissprites);
    }
    fixedcolormap=NULL;frame.flip[0]=0;R_ClearSprites();
    for(int i=0;i<130;i++){mobj_t t={0};t.x=160*FRACUNIT;t.z=i*FRACUNIT;R_ProjectSprite(&t);}
    word(f,vissprite_p-vissprites);vis_words(f,&overflowsprite);R_SortVisSprites();
    for(vissprite_t *v=vsprsortedhead.next;v!=&vsprsortedhead;v=v->next)word(f,v-vissprites);
    fclose(f);
    unsigned char *patch=Z_Malloc(144,PU_STATIC,NULL);memset(patch,0,144);
    patch[0]=8;patch[2]=8;patch[6]=8;
    for(int x=0;x<8;x++) {int offset=40+x*13;memcpy(patch+8+x*4,&offset,4);patch[offset]=0;patch[offset+1]=8;for(int y=0;y<8;y++)patch[offset+3+y]=0x70+(x+y)%16;patch[offset+12]=255;}
    lumpcache[firstspritelump]=patch;
    for(int mode=0;mode<14;mode++) {
        for(int p=0;p<64000;p++)screens[0][p]=(unsigned char)p;
        fuzzpos=0;fixedcolormap=NULL;detailshift=(mode>=6 && mode<=8);colfunc=basecolfunc=detailshift?R_DrawColumnLow:R_DrawColumn;
        mfloorclip=screenheightarray;mceilingclip=negonearray;
        vissprite_t v={0};v.x1=140;v.x2=147;v.scale=FRACUNIT;v.xiscale=FRACUNIT;v.texturemid=8*FRACUNIT;v.colormap=colormaps+256*7;
        if(mode==1 || mode==8)v.colormap=NULL;
        if(mode==2 || mode==7)v.mobjflags=1<<MF_TRANSSHIFT;
        if(mode>=9) {
            short bottom[320],top[320];for(int x=0;x<320;x++){bottom[x]=96;top[x]=93;}
            drawseg_t *d=drawsegs;memset(d,0,sizeof(*d));d->x1=140;d->x2=147;d->scale1=d->scale2=2*FRACUNIT;
            d->silhouette=mode==9?1:mode==10?2:3;d->bsilheight=FRACUNIT;d->tsilheight=7*FRACUNIT;d->sprbottomclip=bottom;d->sprtopclip=top;ds_p=drawsegs+1;
            v.gzt=8*FRACUNIT;if(mode==12){v.gz=2*FRACUNIT;v.gzt=6*FRACUNIT;}if(mode==13)d->scale1=d->scale2=FRACUNIT/2;
            R_DrawSprite(&v);
        }
        else if(mode<3 || mode>=6)R_DrawVisSprite(&v,0,0);
        else {
            state_t state={0};state.sprite=0;state.frame=mode==4?FF_FULLBRIGHT:0;
            players[0].psprites[0].state=&state;players[0].psprites[0].sx=160*FRACUNIT;players[0].psprites[0].sy=100*FRACUNIT;
            players[0].psprites[1].state=&state;players[0].psprites[1].sx=168*FRACUNIT;players[0].psprites[1].sy=100*FRACUNIT;
            players[0].powers[pw_invisibility]=mode==5?129:0;R_DrawPlayerSprites();
            players[0].psprites[0].state=players[0].psprites[1].state=NULL;
        }
        char name[64];snprintf(name,sizeof(name),"draw-edge%d.bin",mode);writefile(directory,name,screens[0],64000);
    }
}
