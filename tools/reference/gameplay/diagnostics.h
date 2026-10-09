// SPDX-License-Identifier: GPL-2.0-only
// Original transient collision globals: diagnostics, excluded from logical world digest.
extern fixed_t tmbbox[4],tmx,tmy,tmdropoffz,shootz,attackrange,aimslope,topslope,bottomslope;
extern mobj_t *tmthing,*shootthing;
extern int tmflags,numspechit,la_damage;
extern line_t *spechit[];
static int line_id(line_t *l) {return l ? (int)(l-lines):-1;}
static void diagnostic_record(FILE *f) {
    long start=ftell(f);word(f,0);long payload=ftell(f);
    word(f,gametic);word(f,validcount);word(f,identity(tmthing));word(f,tmflags);word(f,tmx);word(f,tmy);
    for(int i=0;i<4;i++) word(f,tmbbox[i]);
    word(f,floatok);word(f,tmfloorz);word(f,tmceilingz);word(f,tmdropoffz);word(f,line_id(ceilingline));
    word(f,numspechit);for(int i=0;i<numspechit;i++) word(f,line_id(spechit[i]));
    word(f,identity(linetarget));word(f,identity(shootthing));word(f,shootz);word(f,la_damage);word(f,attackrange);word(f,aimslope);word(f,topslope);word(f,bottomslope);
    long end=ftell(f);fseek(f,start,SEEK_SET);word(f,(int32_t)(end-payload));fseek(f,end,SEEK_SET);
}
