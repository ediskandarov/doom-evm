/* Includes every original am_map function and glyph unchanged; only includes are projected. */
#include "compat.h"
vertex_t *vertexes;
line_t *lines;
sector_t *sectors;
int numvertexes,numlines,numsectors,consoleplayer,gamemap,gameepisode;
int playeringame[4],netgame,deathmatch,singledemo;
player_t players[4];
fixed_t bmaporgx,bmaporgy;
boolean viewactive=true;
fixed_t *finecosine = finesine + FINEANGLES/4;
static int notification[3],loads,unloads;
static const char *patchdir;
int ST_Responder(event_t *e) {notification[0]=e->type;notification[1]=e->data1;notification[2]=e->data2;return 0;}
void *W_CacheLumpName(char *name,int tag) {
    char path[4096]; (void)tag; snprintf(path,sizeof(path),"%s/%s.bin",patchdir,name);
    FILE *f=fopen(path,"rb");if(!f)exit(2);fseek(f,0,SEEK_END);long n=ftell(f);rewind(f);
    void *p=malloc(n);if(fread(p,1,n,f)!=(size_t)n)exit(3);fclose(f);loads++;return p;
}
void Z_ChangeTag(void *p,int tag) {(void)p;(void)tag;unloads++;}
byte *I_AllocLow(int n) {return calloc(1,n);}
void I_Error(char *fmt,...) {(void)fmt;exit(4);}
#include "automap_projection.inc"
static unsigned word(FILE *f) {byte b[4];if(fread(b,1,4,f)!=4)exit(5);return (unsigned)b[0]<<24|(unsigned)b[1]<<16|(unsigned)b[2]<<8|b[3];}
static void out(unsigned n) {byte b[4]={n>>24,n>>16,n>>8,n};fwrite(b,1,4,stdout);}
static void snapshot(int rc,int big) {
    out(automapactive);out(stopped);out(viewactive);out(followplayer);out(grid);out(big);out(cheating);
    out(cheat_amap.p?cheat_amap.p-cheat_amap.sequence:0);out(plr?plr-players:0);
    out(amclock);out(lightlev);out(m_paninc.x);out(m_paninc.y);out(mtof_zoommul);out(ftom_zoommul);
    out(m_x);out(m_y);out(m_x2);out(m_y2);out(m_w);out(m_h);
    out(min_x);out(min_y);out(max_x);out(max_y);out(min_scale_mtof);out(max_scale_mtof);out(scale_mtof);out(scale_ftom);
    out(old_m_x);out(old_m_y);out(old_m_w);out(old_m_h);out(f_oldloc.x);out(f_oldloc.y);out(markpointnum);
    for(int i=0;i<10;i++){out(markpoints[i].x);out(markpoints[i].y);}
    for(int i=0;i<3;i++)out(notification[i]);out(loads/10);out(unloads/10);out(rc);
    for(int i=0;i<4;i++)out(dirtybox[i]);
    char *msg=plr?plr->message:NULL;unsigned n=msg?strlen(msg):0;out(n);if(n)fwrite(msg,1,n,stdout);
    fwrite(screens[0],1,64000,stdout);
}
int main(int argc,char **argv) {
    if(argc!=3)return 6;patchdir=argv[2];FILE *f=fopen(argv[1],"rb");if(!f)return 7;
    gameepisode=word(f);gamemap=word(f);consoleplayer=word(f);netgame=word(f);deathmatch=word(f);singledemo=word(f);
    int allmap=word(f);bmaporgx=word(f);bmaporgy=word(f);
    mobj_t actors[4];
    for(int i=0;i<4;i++){actors[i].x=word(f);actors[i].y=word(f);actors[i].angle=word(f);playeringame[i]=word(f);players[i].powers[pw_invisibility]=word(f);players[i].powers[pw_allmap]=allmap;players[i].mo=&actors[i];}
    numvertexes=word(f);vertexes=calloc(numvertexes,sizeof(*vertexes));
    for(int i=0;i<numvertexes;i++){vertexes[i].x=word(f);vertexes[i].y=word(f);}
    numlines=word(f);lines=calloc(numlines,sizeof(*lines));sector_t *pairs=calloc(2*numlines,sizeof(*pairs));
    for(int i=0;i<numlines;i++){
        vertex_t *v=calloc(2,sizeof(*v));v[0].x=word(f);v[0].y=word(f);v[1].x=word(f);v[1].y=word(f);
        lines[i].v1=v;lines[i].v2=v+1;lines[i].flags=word(f);lines[i].special=word(f);int back=word(f);
        pairs[2*i].floorheight=word(f);pairs[2*i+1].floorheight=word(f);pairs[2*i].ceilingheight=word(f);pairs[2*i+1].ceilingheight=word(f);
        lines[i].frontsector=&pairs[2*i];lines[i].backsector=back?&pairs[2*i+1]:NULL;
    }
    int nt=word(f);mobj_t *things=calloc(nt,sizeof(*things));numsectors=1;sectors=calloc(1,sizeof(*sectors));
    for(int i=0;i<nt;i++){things[i].x=word(f);things[i].y=word(f);things[i].angle=word(f);if(i+1<nt)things[i].snext=&things[i+1];}
    if(nt)sectors[0].thinglist=things;
    V_Init();M_ClearBox(dirtybox);for(int i=0;i<64000;i++)screens[0][i]=(byte)(i*13+(i/320)*7+19);
    int actions=word(f),big=0;out(actions);
    for(int j=0;j<actions;j++) {
        int op=word(f),a=word(f),b=word(f),c=word(f),d=word(f),rc=0;
        switch(op){
        case 0:{event_t ev={a,b,0,0};int wasactive=automapactive;rc=AM_Responder(&ev);if(wasactive&&a==0&&b=='0')big=!big;if(wasactive&&a==0&&b==9)big=0;break;}
        case 1:for(int i=0;i<a;i++)AM_Ticker();break;
        case 2:AM_Drawer();break;
        case 3:actors[a].x=b;actors[a].y=c;actors[a].angle=d;break;
        case 4:AM_Stop();break;
        case 5:gameepisode=a;gamemap=b;AM_Start();break;
        case 6:for(int i=0;i<4;i++)players[i].powers[pw_allmap]=a;break;
        case 7:lines[a].flags=b;break;
        case 8:netgame=a;deathmatch=b;singledemo=c;break;
        case 9:markpoints[a].x=b;markpoints[a].y=c;break;
        case 10:AM_updateLightLev();break;
        case 11:{mline_t l={{a,b},{c,d}};islope_t slope;AM_getIslope(&l,&slope);notification[0]=slope.slp;notification[1]=slope.islp;notification[2]=0;break;}
        default:return 8;
        }
        snapshot(rc,big);
    }
    return 0;
}
