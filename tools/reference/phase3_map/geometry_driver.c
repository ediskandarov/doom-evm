// SPDX-License-Identifier: GPL-2.0-only
static void word(int32_t value) { uint32_t u=(uint32_t)value;unsigned char b[4]={u>>24,u>>16,u>>8,u};if(fwrite(b,1,4,stdout)!=4)exit(3); }
int main(void) {
    int op,n;int32_t a[16];
    while(scanf("%d %d",&op,&n)==2) {
        if(n<0||n>16)exit(3);for(int i=0;i<n;i++)if(scanf("%d",&a[i])!=1)exit(3);
        line_t line={0};vertex_t vertex={0};divline_t d1={0},d2={0};
        if(op==0){word(1);word(P_AproxDistance(a[0],a[1]));}
        else if(op==1){vertex.x=a[2];vertex.y=a[3];line.v1=&vertex;line.dx=a[4];line.dy=a[5];word(1);word(P_PointOnLineSide(a[0],a[1],&line));}
        else if(op==2){vertex.x=a[4];vertex.y=a[5];line.v1=&vertex;line.dx=a[6];line.dy=a[7];line.slopetype=a[8];word(1);word(P_BoxOnLineSide(a,&line));}
        else if(op==3||op==5){d1=(divline_t){a[2],a[3],a[4],a[5]};word(1);word(op==3?P_PointOnDivlineSide(a[0],a[1],&d1):P_DivlineSide(a[0],a[1],&d1));}
        else if(op==4||op==6){d1=(divline_t){a[0],a[1],a[2],a[3]};d2=(divline_t){a[4],a[5],a[6],a[7]};word(1);word(op==4?P_InterceptVector(&d1,&d2):P_InterceptVector2(&d1,&d2));}
        else if(op==7){sector_t front={0},back={0};front.floorheight=a[0];front.ceilingheight=a[1];back.floorheight=a[2];back.ceilingheight=a[3];line.frontsector=&front;line.backsector=&back;line.sidenum[1]=a[4]?0:-1;opentop=11;openbottom=22;openrange=33;lowfloor=44;P_LineOpening(&line);word(4);word(opentop);word(openbottom);word(openrange);word(lowfloor);}
        else exit(3);
    }return ferror(stdin)?3:0;
}
