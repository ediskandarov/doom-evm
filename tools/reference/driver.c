/* GPL-2.0-only. Host command adapter; original algorithm bodies are generated separately. */
static unsigned read16(const unsigned char *p) { return p[0] | ((unsigned)p[1]<<8); }
static int signed16(const unsigned char *p) { unsigned v=read16(p); return v<32768 ? (int)v : (int)v-65536; }
static void load_nodes(const char *path, int count) {
    FILE *file=fopen(path,"rb"); if(!file || count<1 || count>32768) exit(2);
    fseek(file,0,SEEK_END); long size=ftell(file); rewind(file);
    if(size<0 || size%28 || size/28>32767) exit(2);
    numnodes=(int)(size/28); nodes=calloc((size_t)numnodes+1,sizeof(*nodes));
    subsectors=calloc((size_t)count,sizeof(*subsectors));
    if(!nodes || !subsectors) exit(2);
    for(int i=0;i<numnodes;i++) {
        unsigned char b[28]; if(fread(b,1,28,file)!=28) exit(2);
        nodes[i].x=signed16(b)*65536; nodes[i].y=signed16(b+2)*65536;
        nodes[i].dx=signed16(b+4)*65536; nodes[i].dy=signed16(b+6)*65536;
        for(int s=0;s<2;s++) { unsigned child=read16(b+24+s*2);
            if((child&NF_SUBSECTOR) ? (child&32767)>=(unsigned)count : child>=(unsigned)numnodes) exit(2);
            nodes[i].children[s]=(unsigned short)child;
        }
    }
    fclose(file);
}
int main(int argc, char **argv) {
    if(argc==3) load_nodes(argv[1],atoi(argv[2]));
    else { numnodes=1; nodes=calloc(1,sizeof(*nodes)); subsectors=calloc(2,sizeof(*subsectors)); nodes[0].dy=65536; nodes[0].children[0]=32768; nodes[0].children[1]=32769; }
    char line[256],fn[64]; long long a[6];
    while(fgets(line,sizeof(line),stdin)) {
        memset(a,0,sizeof(a)); if(sscanf(line,"%63s %lld %lld %lld %lld %lld %lld",fn,a,a+1,a+2,a+3,a+4,a+5)<1) return 2;
        trace_count=0;
        if(setjmp(failure)) { puts("error"); continue; }
        if(!strcmp(fn,"FixedMul")) printf("ok %d\n",FixedMul((int)a[0],(int)a[1]));
        else if(!strcmp(fn,"FixedDiv")) printf("ok %d\n",FixedDiv((int)a[0],(int)a[1]));
        else if(!strcmp(fn,"FixedDiv2")) printf("ok %d\n",FixedDiv2((int)a[0],(int)a[1]));
        else if(!strcmp(fn,"SlopeDiv")) printf("ok %d\n",SlopeDiv((unsigned)a[0],(unsigned)a[1]));
        else if(!strcmp(fn,"R_PointOnSide")) { node_t n={(int)a[2],(int)a[3],(int)a[4],(int)a[5],{0,0}}; printf("ok %d\n",R_PointOnSide((int)a[0],(int)a[1],&n)); }
        else if(!strcmp(fn,"R_PointToAngle2")) printf("ok %u\n",R_PointToAngle2((int)a[0],(int)a[1],(int)a[2],(int)a[3]));
        else if(!strcmp(fn,"R_PointInSubsector") || !strcmp(fn,"BSPPath")) {
            int leaf=(int)(R_PointInSubsector((int)a[0],(int)a[1])-subsectors);
            if(!strcmp(fn,"BSPPath")) { printf("ok"); for(int i=0;i<trace_count;i++) printf(" %d",trace[i]); printf(" %d\n",leaf|NF_SUBSECTOR); }
            else printf("ok %d\n",leaf);
        } else return 2;
    }
    free(nodes); free(subsectors); return 0;
}
