/* Included after the shared native host adapters. Only scene setup/output here. */
extern int rw_angle1;
extern short openings[];
extern fixed_t rw_scalestep, rw_scale, rw_distance, rw_offset, rw_midtexturemid, rw_toptexturemid, rw_bottomtexturemid;
extern fixed_t pixhigh,pixlow,pixhighstep,pixlowstep,topfrac,topstep,bottomfrac,bottomstep;
extern int worldtop,worldbottom,worldhigh,worldlow,rw_x,rw_stopx;
extern angle_t rw_normalangle,rw_centerangle;
extern boolean segtextured,markfloor,markceiling,maskedtexture;
extern int toptexture,bottomtexture,midtexture;
int main(int argc,char **argv) {
    if(argc!=26) I_Error("synthetic WAD output-directory 23 input fields");
    int a[23];for(int i=0;i<23;i++)a[i]=atoi(argv[i+3]);
    char *files[]={argv[1],NULL};W_InitMultipleFiles(files);
    gamemode=retail;gamemission=doom;
    screens[0]=calloc(1,64000);screens[1]=calloc(1,64000);
    char *sprite_names[NUMSPRITES+1];memcpy(sprite_names,sprnames,NUMSPRITES*sizeof(*sprite_names));sprite_names[NUMSPRITES]=NULL;
    R_Init();R_InitSprites(sprite_names);R_ExecuteSetViewSize();
    skyflatnum=R_FlatNumForName("F_SKY1");skytexture=R_TextureNumForName("SKY1");
    numvertexes=2;vertexes=calloc(2,sizeof(*vertexes));
    vertexes[0]=(vertex_t){128*65536,128*65536};vertexes[1]=(vertex_t){128*65536,-128*65536};
    if(a[21]==1){vertexes[0]=(vertex_t){-128*65536,128*65536};vertexes[1]=(vertex_t){128*65536,128*65536};}
    if(a[21]==2){vertexes[0].x=192*65536;vertexes[1].x=64*65536;}
    numsectors=2;sectors=calloc(2,sizeof(*sectors));
    sectors[0].floorheight=a[0]*65536;sectors[0].ceilingheight=a[1]*65536;
    sectors[1].floorheight=a[2]*65536;sectors[1].ceilingheight=a[3]*65536;
    sectors[0].floorpic=sectors[1].floorpic=1;
    sectors[0].ceilingpic=a[12]?skyflatnum:2;sectors[1].ceilingpic=a[13]?skyflatnum:2;
    sectors[0].lightlevel=a[14];sectors[1].lightlevel=a[15];
    numsides=1;sides=calloc(1,sizeof(*sides));sides[0].midtexture=a[6];sides[0].toptexture=a[7];sides[0].bottomtexture=a[8];
    sides[0].rowoffset=a[9]*65536;sides[0].textureoffset=a[10]*65536;sides[0].sector=sectors;
    numlines=1;lines=calloc(1,sizeof(*lines));lines[0].flags=a[5];lines[0].v1=vertexes;lines[0].v2=vertexes+1;
    numsegs=1;segs=calloc(1,sizeof(*segs));segs[0].v1=vertexes;segs[0].v2=vertexes+1;segs[0].offset=a[11]*65536;
    segs[0].angle=R_PointToAngle2(vertexes[0].x,vertexes[0].y,vertexes[1].x,vertexes[1].y);
    segs[0].sidedef=sides;segs[0].linedef=lines;segs[0].frontsector=sectors;segs[0].backsector=a[4]?sectors+1:NULL;
    mobj_t camera={0};camera.angle=a[21]==1?ANG90:0;players[0].mo=&camera;players[0].viewz=41*65536;
    players[0].fixedcolormap=a[18]<0?0:a[18];players[0].extralight=a[19];
    if(a[20])texturetranslation[1]=2;
    R_SetupFrame(players);R_ClearClipSegs();R_ClearDrawSegs();R_ClearPlanes();
    frontsector=sectors;backsector=segs[0].backsector;curline=segs;
    floorplane=sectors[0].floorheight<viewz?R_FindPlane(sectors[0].floorheight,1,sectors[0].lightlevel):NULL;
    ceilingplane=sectors[0].ceilingheight>viewz||sectors[0].ceilingpic==skyflatnum?R_FindPlane(sectors[0].ceilingheight,sectors[0].ceilingpic,sectors[0].lightlevel):NULL;
    rw_angle1=R_PointToAngle(vertexes[0].x,vertexes[0].y);
    if(a[22]){rw_scalestep=12345;drawsegs[0].scalestep=54321;}
    R_StoreWallRange(a[16],a[17]);
    writefile(argv[2],"pixels.bin",screens[0],64000);geometry_outputs(argv[2]);
    int32_t globals[]={segtextured,markfloor,markceiling,maskedtexture,toptexture,bottomtexture,midtexture,
        (int32_t)rw_normalangle,rw_angle1,rw_x,rw_stopx,(int32_t)rw_centerangle,rw_offset,rw_distance,rw_scale,rw_scalestep,
        rw_midtexturemid,rw_toptexturemid,rw_bottomtexturemid,worldtop,worldbottom,worldhigh,worldlow,
        pixhigh,pixlow,pixhighstep,pixlowstep,topfrac,topstep,bottomfrac,bottomstep,lines[0].flags,(int)(lastopening-openings)};
    FILE *f=output(argv[2],"globals.bin");for(unsigned i=0;i<sizeof(globals)/sizeof(*globals);i++)word(f,globals[i]);fclose(f);
    return 0;
}
