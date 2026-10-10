/* This host seeds buffers and invokes the unchanged original video functions. */
#include "compat.h"
#include <setjmp.h>

static jmp_buf failure;
static byte *allocation;
static int error_seen;

byte *I_AllocLow(int length) {
    allocation = calloc(1, (size_t)length);
    if (!allocation) exit(2);
    return allocation;
}
void I_Error(char *fmt, ...) {
    (void)fmt;
    error_seen = 1;
    longjmp(failure, 1);
}
static uint32_t read32(FILE *file) {
    byte b[4];
    if (fread(b,1,4,file)!=4) exit(3);
    return ((uint32_t)b[0]<<24)|((uint32_t)b[1]<<16)|((uint32_t)b[2]<<8)|b[3];
}
static void write32(uint32_t value) {
    byte b[4] = { value>>24, value>>16, value>>8, value };
    if (fwrite(b,1,4,stdout)!=4) exit(4);
}
static byte *read_patch(const char *directory, int id) {
    char path[4096];
    snprintf(path,sizeof(path),"%s/patch-%d.bin",directory,id);
    FILE *f=fopen(path,"rb");
    if (!f) exit(5);
    fseek(f,0,SEEK_END); long size=ftell(f); rewind(f);
    byte *data=malloc((size_t)size);
    if (!data || fread(data,1,(size_t)size,f)!=(size_t)size) exit(6);
    fclose(f); return data;
}
int main(int argc, char **argv) {
    if (argc!=3 || sizeof(int)!=4 || sizeof(short)!=2) return 1;
    FILE *cases=fopen(argv[1],"rb"); if (!cases) return 7;
    uint32_t count=read32(cases);
    for (uint32_t row=0; row<count; ++row) {
        int32_t a[13];
        for (int i=0;i<13;i++) a[i]=(int32_t)read32(cases);
        screens[4]=NULL; V_Init();
        /* V_Init allocates exactly four contiguous 64000-byte buffers; screen4
         * is caller-owned in the original, including ST_Init's 320x32 backing. */
        if (screens[1]!=screens[0]+64000 || screens[3]!=screens[0]+192000 || screens[4]) return 8;
        size_t lengths[5]={64000,64000,64000,64000,(size_t)320*a[11]};
        screens[4]=calloc(1,lengths[4]);
        for (int s=0;s<5;s++) for(size_t i=0;i<lengths[s];i++)
            screens[s][i]=(byte)(i*13+(i/320)*7+s*41+a[10]);
        M_ClearBox(dirtybox);
        byte *patch=a[9]>=0?read_patch(argv[2],a[9]):NULL;
        size_t blocksize=(a[4]>=0&&a[5]>=0)?(size_t)a[4]*a[5]:0;
        byte *block=malloc(blocksize?blocksize:1);
        for(size_t i=0;i<blocksize;i++) block[i]=(byte)(i*17+a[10]+3);
        error_seen=0;
        if (!setjmp(failure)) {
            switch(a[0]) {
                case 0: break;
                case 1: V_MarkRect(a[1],a[2],a[4],a[5]); break;
                case 2: V_CopyRect(a[1],a[2],a[3],a[4],a[5],a[6],a[7],a[8]); break;
                case 3: V_DrawPatch(a[1],a[2],a[3],(patch_t*)patch); break;
                case 4: V_DrawPatchFlipped(a[1],a[2],a[3],(patch_t*)patch); break;
                case 5: V_DrawPatchDirect(a[1],a[2],a[3],(patch_t*)patch); break;
                case 6: V_DrawBlock(a[1],a[2],a[3],a[4],a[5],block); break;
                case 7: V_GetBlock(a[1],a[2],a[3],a[4],a[5],block); break;
                default: return 9;
            }
        }
        for(int i=0;i<4;i++) write32((uint32_t)dirtybox[i]);
        write32((uint32_t)error_seen);
        for(int i=0;i<5;i++) { write32((uint32_t)lengths[i]); fwrite(screens[i],1,lengths[i],stdout); }
        size_t getsize=a[0]==7&&!error_seen?blocksize:0;
        write32((uint32_t)getsize); fwrite(block,1,getsize,stdout);
        free(patch); free(block); free(screens[4]); free(allocation);
    }
    /* Original fixed table, exported rather than reproduced mathematically. */
    fwrite(gammatable,1,sizeof(gammatable),stdout);
    fclose(cases); return 0;
}
