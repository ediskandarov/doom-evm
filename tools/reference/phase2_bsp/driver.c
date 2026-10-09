/* SPDX-License-Identifier: GPL-2.0-only. No clip algorithm in this adapter. */
int main(void){
 char op[16];int a,b;
 while(scanf("%15s %d %d",op,&a,&b)==3){
  printf("%s",op);
  if(!strcmp(op,"clear")){viewwidth=a;R_ClearClipSegs();}
  else if(!strcmp(op,"solid"))R_ClipSolidWallSegment(a,b);
  else if(!strcmp(op,"pass"))R_ClipPassWallSegment(a,b);
  else return 2;
  printf(" | %ld",(long)(newend-solidsegs));
  for(cliprange_t *r=solidsegs;r<newend;r++)printf(" %d %d",r->first,r->last);
  putchar('\n');
 }
 return 0;
}
