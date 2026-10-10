static void word(uint32_t v){putchar(v>>24);putchar(v>>16);putchar(v>>8);putchar(v);}
int main(void){
    unsigned n,p,key,get;
    while(scanf("%u%u%u%u",&n,&p,&key,&get)==4){
        unsigned char seq[64]; if(n>64||p>=n)abort();
        for(unsigned i=0;i<n;i++){unsigned v;if(scanf("%u",&v)!=1)abort();seq[i]=v;}
        cheatseq_t cht={seq,seq+p};int rc=cht_CheckCheat(&cht,(char)key);
        char buffer[64];memset(buffer,0xaa,sizeof(buffer));unsigned size=0;
        if(get){cht_GetParam(&cht,buffer);size=sizeof(buffer);while(size && (unsigned char)buffer[size-1]==0xaa)size--;}
        word(rc);word(cht.p-seq);word(n);fwrite(seq,1,n,stdout);word(size);fwrite(buffer,1,size,stdout);
    }
}
