/* GPL-2.0-only. Input/output adapters; numerical algorithms remain in extracted C. */
static void out(int64_t n){printf("%lld ",(long long)n);}
static void viewdump(void){
    out(viewwidth);out(viewheight);out(scaledviewwidth);out(detailshift);out(centerx);out(centery);out(centerxfrac);out(centeryfrac);out(projection);out(viewwindowx);out(viewwindowy);out(clipangle);out(pspritescale);out(pspriteiscale);
    for(int i=0;i<4096;i++)out(viewangletox[i]);
    for(int i=0;i<=viewwidth;i++)out(xtoviewangle[i]);
    for(int i=0;i<viewheight;i++)out(yslope[i]);
    for(int i=0;i<viewwidth;i++)out(distscale[i]);
    for(int i=0;i<scaledviewwidth;i++)out(columnofs[i]);
    for(int i=0;i<viewheight;i++)out(ylookup[i]-framebuffer);
    for(int i=0;i<viewwidth;i++)out(screenheightarray[i]);
    for(int i=0;i<16;i++)for(int j=0;j<48;j++)out((scalelight[i][j]-colormaps)/256);
    for(int i=0;i<16;i++)for(int j=0;j<128;j++)out((zlight[i][j]-colormaps)/256);
}
int main(void){
    char fn[32]; long long a[8];
    while(scanf("%31s",fn)==1){
        int count=!strcmp(fn,"view")?2:!strcmp(fn,"dist")?4:!strcmp(fn,"scale")?6:!strcmp(fn,"setup")?7:6;
        for(int i=0;i<count;i++)if(scanf("%lld",a+i)!=1)return 2;
        if(!strcmp(fn,"view")){setblocks=a[0];setdetail=a[1];R_InitLightTables();R_ExecuteSetViewSize();viewdump();}
        else if(!strcmp(fn,"dist")){viewx=a[0];viewy=a[1];out(R_PointToDist(a[2],a[3]));}
        else if(!strcmp(fn,"scale")){viewangle=a[0];projection=a[1];detailshift=a[2];rw_normalangle=a[4];rw_distance=a[5];out(R_ScaleFromGlobalAngle(a[3]));}
        else if(!strcmp(fn,"seg")){vertex_t v1={(int)a[2],(int)a[3]},v2={(int)a[4],(int)a[5]};seg_t seg={&v1,&v2};out(R_PointOnSegSide(a[0],a[1],&seg));}
        else if(!strcmp(fn,"setup")){mobj_t mo={(int)a[0],(int)a[1],(unsigned)a[3]};player_t p={&mo,(int)a[4],(int)a[2],(int)a[5]};memset(scalelightfixed,0,sizeof(scalelightfixed));validcount=1;framecount=9;sscount=99;viewangleoffset=a[6];R_SetupFrame(&p);out(viewx);out(viewy);out(viewz);out(viewangle);out(extralight);out(viewsin);out(viewcos);out(fixedcolormap?(fixedcolormap-colormaps)/256:-1);out(framecount);out(validcount);out(sscount);for(int i=0;i<48;i++)out(scalelightfixed[i]?(scalelightfixed[i]-colormaps)/256:-1);}
        else return 3;
        putchar('\n');
    }
    return 0;
}
