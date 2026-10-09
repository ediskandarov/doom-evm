/* GPL-2.0-only. Declarative inputs and byte-state observation; no renderer algorithms. */
static void word(int32_t v){uint32_t u=(uint32_t)v;for(int i=3;i>=0;i--)putchar((u>>(i*8))&255);}
static void setup(int32_t *a){
 viewwidth=8;viewheight=8;centery=4;centerxfrac=4*65536;viewx=12345;viewy=-54321;viewz=65536;viewangle=(uint32_t)a[6];detailshift=a[7];pspriteiscale=65536;
 fixedcolormap=a[5]<0?NULL:colormaps+a[5]*256;
 for(int y=0;y<200;y++){yslope[y]=(y+1)*16384;ylookup[y]=framebuffer+y*320;}
 for(int x=0;x<320;x++){distscale[x]=65536+x*8192;xtoviewangle[x]=(uint32_t)x*0x1000000;columnofs[x]=x;}
 for(int i=0;i<34*256;i++)colormaps[i]=(i%256+(i/256)*7)&255;
 for(int i=0;i<16;i++)for(int j=0;j<128;j++)zlight[i][j]=colormaps+((i+j)%32)*256;
 for(int i=0;i<4096;i++){flats[0][i]=(i*13)&255;flats[1][i]=(i*17+23)&255;}
 for(int x=0;x<128;x++)for(int y=0;y<128;y++)sky[x][y]=(x*3+y*5)&255;
 spanfunc=detailshift?R_DrawSpanLow:R_DrawSpan;colfunc=detailshift?R_DrawColumnLow:R_DrawColumn;
 if(a[0]==6){viewwidth=a[1];viewheight=a[2];centerxfrac=(viewwidth/2)*65536;}
 R_ClearPlanes();ds_source=flats[0];planezlight=zlight[3];
}
static void dump(void){
 word(viewwidth);word(viewheight);for(int x=0;x<viewwidth;x++){word(floorclip[x]);word(ceilingclip[x]);}
 int32_t values[]={ds_y,ds_x1,ds_x2,ds_xfrac,ds_yfrac,ds_xstep,ds_ystep,ds_colormap?(int32_t)((ds_colormap-colormaps)/256):-1,dc_x,dc_yl,dc_yh,dc_iscale,dc_texturemid,dc_colormap?(int32_t)((dc_colormap-colormaps)/256):-1,basexscale,baseyscale,planeheight};
 for(unsigned i=0;i<sizeof(values)/sizeof(*values);i++)word(values[i]);
 for(int y=0;y<200;y++){word(cachedheight[y]);word(cacheddistance[y]);word(cachedxstep[y]);word(cachedystep[y]);word(spanstart[y]);}
 word(lastvisplane-visplanes);
 for(visplane_t *p=visplanes;p<lastvisplane;p++){word(p->height);word(p->picnum);word(p->lightlevel);word(p->minx);word(p->maxx);fwrite((byte*)p+offsetof(visplane_t,pad1),1,322,stdout);fwrite((byte*)p+offsetof(visplane_t,pad3),1,322,stdout);}
 fwrite(framebuffer,1,8*320,stdout);
}
int main(int argc,char **argv){
 if(argc!=11)return 2;int32_t a[10];for(int i=0;i<10;i++)a[i]=(int32_t)strtoll(argv[i+1],NULL,0);setup(a);
 if(a[0]==0){planeheight=a[1];if(a[8]){cachedheight[a[2]]=a[1];cacheddistance[a[2]]=a[8];cachedxstep[a[2]]=123;cachedystep[a[2]]=-456;if(a[9])R_ClearPlanes();}R_MapPlane(a[2],a[3],a[4]);}
 else if(a[0]==1){planeheight=2*65536;for(int y=0;y<200;y++)spanstart[y]=1;R_MakeSpans(a[1],a[2],a[3],a[4],a[8]);}
 else if(a[0]==2){
  visplane_t *p=R_FindPlane(a[1],a[2]?skyflatnum:0,a[3]);p=R_CheckPlane(p,0,7);
  for(int x=0;x<8;x++){p->top[x]=1+x%3;p->bottom[x]=5+x%2;}
  extralight=a[4];R_DrawPlanes();
 }
 else if(a[0]==3||a[0]==4){
  visplane_t *p=R_FindPlane(123,0,77);p=R_CheckPlane(p,1,5);p->top[3]=2;
  R_CheckPlane(p,2,4);R_FindPlane(99,skyflatnum,100);R_FindPlane(-999,skyflatnum,-10);
  if(a[0]==4){dump();return 0;}
  p->pad1=17;p->pad2=18;p->bottom[7]=91;cachedheight[2]=9;cacheddistance[2]=34;cachedxstep[2]=56;cachedystep[2]=78;spanstart[2]=4;
  R_ClearPlanes();R_FindPlane(456,1,88);
 }
 else if(a[0]==5){for(int i=0;i<128;i++)R_FindPlane(i,0,0);}
 else if(a[0]!=6)return 3;dump();return 0;
}
