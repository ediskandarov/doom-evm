/* SPDX-License-Identifier: GPL-2.0-only */
int main(void){
    int32_t a[8];
    while(scanf("%d",&a[0])==1){
        for(int i=1;i<8;++i)if(scanf("%d",&a[i])!=1)return 1;
        sector.floorheight=a[0];sector.ceilingheight=a[1];calls=0;hash=2166136261u;obstruction=a[7];
        result_e result=T_MovePlane(&sector,a[2],a[3],a[4],a[5],a[6]);
        for(int i=0;i<8;++i)word(a[i]);word(result);word(sector.floorheight);word(sector.ceilingheight);word(calls);word(hash);
    }return ferror(stdout)?1:0;
}
