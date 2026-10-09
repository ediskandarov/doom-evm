/* Original functions compiled without alteration. Host pointers are 64 bit; disk records retain original 16/32-bit widths. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <stdarg.h>
#include <alloca.h>
#include <math.h>
typedef unsigned char byte;
typedef int32_t fixed_t;
typedef uint32_t angle_t;
#define FRACBITS 16
#define FRACUNIT 65536
#define MININT INT32_MIN
#define MAXINT INT32_MAX
#define PU_STATIC 1
#define PU_CACHE 2
#define PU_LEVEL 3
#define SHORT(x) (x)
#define LONG(x) (x)
#define ML_TWOSIDED 4
#define BOXTOP 0
#define BOXBOTTOM 1
#define BOXLEFT 2
#define BOXRIGHT 3
#define ST_HORIZONTAL 0
#define ST_VERTICAL 1
#define ST_POSITIVE 2
#define ST_NEGATIVE 3
#pragma pack(push,1)
typedef struct { short width,height,leftoffset,topoffset; int columnofs[1]; } patch_t;
typedef struct { byte topdelta,length; } column_t;
typedef struct {short x,y;} mapvertex_t;
typedef struct {short v1,v2,flags,special,tag,sidenum[2];} maplinedef_t;
typedef struct {short textureoffset,rowoffset; char toptexture[8],bottomtexture[8],midtexture[8]; short sector;} mapsidedef_t;
typedef struct {short v1,v2,angle,linedef,side,offset;} mapseg_t;
typedef struct {short numsegs,firstseg;} mapsubsector_t;
typedef struct {short floorheight,ceilingheight;char floorpic[8],ceilingpic[8];short lightlevel,special,tag;} mapsector_t;
typedef struct {short x,y,dx,dy,bbox[2][4];unsigned short children[2];} mapnode_t;
#pragma pack(pop)
typedef struct {int originx,originy,patch;} texpatch_t;
typedef struct {char name[8];short width,height,patchcount;texpatch_t patches[1];} texture_t;
typedef struct {fixed_t x,y;} vertex_t;
typedef struct {fixed_t floorheight,ceilingheight;short floorpic,ceilingpic;short lightlevel,special,tag;void*thinglist;} sector_t;
typedef struct {fixed_t textureoffset,rowoffset;short toptexture,bottomtexture,midtexture;sector_t*sector;} side_t;
typedef struct {vertex_t*v1,*v2;fixed_t dx,dy;short flags,special,tag;short sidenum[2];fixed_t bbox[4];int slopetype;sector_t*frontsector,*backsector;} line_t;
typedef struct {vertex_t*v1,*v2;fixed_t offset;angle_t angle;side_t*sidedef;line_t*linedef;sector_t*frontsector,*backsector;} seg_t;
typedef struct {sector_t*sector;short numlines,firstline;} subsector_t;
typedef struct {fixed_t x,y,dx,dy,bbox[2][4];unsigned short children[2];} node_t;
int firstflat,lastflat,numflats,firstspritelump,lastspritelump,numspritelumps,numtextures;
texture_t** textures;
int *texturewidthmask,*texturecompositesize;
short **texturecolumnlump;
unsigned short **texturecolumnofs;
byte **texturecomposite;
int *flattranslation;
fixed_t *spritewidth,*spriteoffset,*spritetopoffset;
int numvertexes,numsectors,numsides,numlines,numsegs,numsubsectors,numnodes;
vertex_t*vertexes;sector_t*sectors;side_t*sides;line_t*lines;seg_t*segs;subsector_t*subsectors;node_t*nodes;
static byte*wad;static int lumpcount;static byte**lumpdata;static int*lumpsize;static char(*lumpnames)[8];static int fill=0;
static void I_Error(const char*fmt,...) {va_list ap;va_start(ap,fmt);vfprintf(stderr,fmt,ap);va_end(ap);exit(2);}
static void *Z_Malloc(size_t n,int tag,void*user) {(void)tag;void*p=malloc(n?n:1);if(!p)abort();memset(p,fill,n);if(user)*(void**)user=p;return p;}
static void Z_Free(void*p){(void)p;}
static void Z_ChangeTag(void*p,int tag){(void)p;(void)tag;}
static void *W_CacheLumpNum(int n,int tag){(void)tag;if(n<0||n>=lumpcount)I_Error("bad lump");return lumpdata[n];}
static int W_LumpLength(int n){return lumpsize[n];}
typedef struct {int handle,position,size;char name[8];} lumpinfo_t;
static lumpinfo_t*lumpinfo;static int numlumps;
static char*strupr(char*s){for(char*p=s;*p;p++)if(*p>='a'&&*p<='z')*p-=32;return s;}
int W_CheckNumForName(char*);
int W_GetNumForName(char*);
int R_FlatNumForName(char*);
int R_TextureNumForName(char*);
fixed_t FixedDiv2(fixed_t,fixed_t);
