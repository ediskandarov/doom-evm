/* HUD-only oracle: original widgets and mechanically projected single-player HU functions. */
#include "compat.h"
#include "../../../original/DOOM/linuxdoom-1.10/hu_lib.h"
#include "../../../original/DOOM/linuxdoom-1.10/hu_stuff.h"
#include "../../../original/DOOM/linuxdoom-1.10/d_englsh.h"
int viewwindowx, viewwindowy, viewwidth, viewheight;
boolean automapactive;
int showMessages, gamemode, gameepisode, gamemap;
enum {shareware, registered, commercial, retail};
typedef struct {char *message;} player_t;
static player_t players[1];
static int consoleplayer;
static player_t *plr;
patch_t *hu_font[HU_FONTSIZE];
static hu_textline_t w_title;
static hu_stext_t w_message;
static boolean chat_on;
static boolean message_on, message_dontfuckwithme, message_nottobefuckedwith, headsupactive;
static int message_counter;
static const char *fontdir;
void *W_CacheLumpName(char *name, int tag) {
    (void)tag; char path[4096]; snprintf(path,sizeof(path),"%s/%s.bin",fontdir,name);
    FILE *f=fopen(path,"rb"); if(!f) exit(2); fseek(f,0,SEEK_END); long n=ftell(f); rewind(f);
    void *p=malloc(n); if(fread(p,1,n,f)!=(size_t)n) exit(3); fclose(f); return p;
}
#define PU_STATIC 1
/* HU_Init's keyboard translation selection is outside the no-chat projection. */
static boolean french;
static const char *shiftxform, *french_shiftxform, *english_shiftxform;
#include "hud_projection.inc"
byte *I_AllocLow(int n) {return calloc(1,n);}
void I_Error(char *fmt, ...) {(void)fmt; exit(4);}
void R_VideoErase(unsigned ofs, int count) {
    if (ofs+(unsigned)count>64000) exit(5);
    memcpy(screens[0]+ofs,screens[1]+ofs,count);
}
static unsigned word(FILE *f) {
    byte b[4]; if(fread(b,1,4,f)!=4) exit(6);
    return (unsigned)b[0]<<24|(unsigned)b[1]<<16|(unsigned)b[2]<<8|b[3];
}
static void out(unsigned n) {byte b[4]={n>>24,n>>16,n>>8,n}; fwrite(b,1,4,stdout);}
static void line(hu_textline_t *t) {
    out(t->x);out(t->y);out(t->len);out(t->needsupdate); fwrite(t->l,1,81,stdout);
}
int main(int argc,char **argv) {
    if(argc!=3)return 7; fontdir=argv[2]; HU_Init(); FILE *f=fopen(argv[1],"rb"); if(!f)return 8;
    unsigned count=word(f);
    for(unsigned k=0;k<count;k++) {
        V_Init(); for(int s=0;s<2;s++)for(int i=0;i<64000;i++)screens[s][i]=(byte)(i*13+(i/320)*7+s*41+19);
        M_ClearBox(dirtybox); memset(&w_message,0,sizeof(w_message)); memset(&w_title,0,sizeof(w_title));
        headsupactive=message_on=message_dontfuckwithme=message_nottobefuckedwith=false; message_counter=0;
        gamemode=1;gameepisode=1;gamemap=1;showMessages=1;automapactive=false;
        viewwindowx=0;viewwindowy=0;viewwidth=320;viewheight=168;players[0].message=NULL;
        HU_Start(); unsigned actions=word(f), eaten=0;
        for(unsigned j=0;j<actions;j++) {
            int op=word(f),a=word(f),b=word(f),c=word(f),d=word(f); unsigned n=word(f);
            char *text=calloc(1,n+1); if(fread(text,1,n,f)!=n)return 9;
            switch(op) {
                case 0: gamemode=a;gameepisode=b;gamemap=c; HU_Start();break;
                case 1: players[0].message=n?text:NULL;break;
                case 2: showMessages=a;message_dontfuckwithme=b;break;
                case 3: for(int i=0;i<a;i++)HU_Ticker();break;
                case 4: {event_t ev={a,b,0,0};if(HU_Responder(&ev))eaten++;break;}
                case 5: automapactive=a;HU_Drawer();break;
                case 6: viewwindowx=a;viewwindowy=b;viewwidth=c;viewheight=d;HU_Erase();break;
                case 7: HU_Stop();break;
                case 8: HUlib_initSText(&w_message,a,b,c,hu_font,33,&message_on);break;
                case 9: {char *prefix=calloc(1,a+1);memcpy(prefix,text,a);HUlib_addMessageToSText(&w_message,prefix,text+a);break;}
                case 10: HUlib_initTextLine(&w_title,a,b,hu_font,33);for(unsigned i=0;i<n;i++)HUlib_addCharToTextLine(&w_title,text[i]);HUlib_drawTextLine(&w_title,c);break;
                case 11: HUlib_clearTextLine(&w_title);break;
                case 12: for(int i=0;i<a;i++)HUlib_delCharFromTextLine(&w_title);break;
                default:return 10;
            }
            /* Every action emits a snapshot, so overwritten intermediate states remain checked. */
            out(headsupactive);out(message_on);out(message_dontfuckwithme);out(message_nottobefuckedwith);
            out(message_counter);out(eaten);out(w_message.h);out(w_message.cl);out(w_message.laston);
            unsigned pending=players[0].message?strlen(players[0].message):0;out(pending);if(pending)fwrite(players[0].message,1,pending,stdout);
            for(int i=0;i<4;i++)line(&w_message.l[i]);line(&w_title);
            for(int i=0;i<4;i++)out(dirtybox[i]);fwrite(screens[0],1,64000,stdout);
            /* text pointers intentionally live until process exit, like the original borrowed message pointer. */
        }
        free(screens[0]);
    }
    fclose(f);return 0;
}
