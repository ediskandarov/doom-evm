#include "hu_lib.h"
int main(int argc,char **argv){
    if(argc!=3)return 1;strcpy(resource_dir,argv[2]);
    FILE *f=fopen(argv[1],"rb");if(!f)return 2;
    V_Init();ST_Init();M_ClearRandom();
    for(int i=0;i<64000;i++)screens[0][i]=(byte)(i*13+(i/320)*7+19);
    players[0].mo=&mo;players[0].health=37;mo.health=29;mo.angle=0xabcdef01;mo.x=-65536;mo.y=0x12345678;
    players[0].weaponowned[0]=players[0].weaponowned[1]=1;players[0].readyweapon=1;
    for(int i=0;i<4;i++){players[0].ammo[i]=i+1;players[0].maxammo[i]=(int[]){400,100,600,100}[i];}
    for(int i=0;i<6;i++)players[0].cards[i]=(i%2)==0;
    ST_Start();
    patch_t *font[63];for(int i=0;i<63;i++){char name[9];sprintf(name,"STCFN%03d",i+33);font[i]=W_CacheLumpName(name,1);}
    hu_stext_t text;boolean texton=true;HUlib_initSText(&text,0,0,1,font,33,&texton);
    uint32_t count=read32(f);
    for(uint32_t row=0;row<count;row++){
        uint32_t n=read32(f);
        for(uint32_t i=0;i<n;i++){int key=fgetc(f);if(key==EOF)abort();event_t ev={ev_keydown,key,0,0};ST_Responder(&ev);}
        ST_Ticker();ST_Drawer(false,false);
        /* Observe cheat message through unchanged original text widgets. */
        HUlib_addMessageToSText(&text,"",players[0].message);players[0].message=NULL;
        HUlib_drawSText(&text);
        fwrite(screens[0],1,64000,stdout);fwrite(screens[4],1,10240,stdout);fwrite(palette_rgb,1,768,stdout);
        write32(st_faceindex);write32(st_palette);
    }
    return 0;
}
