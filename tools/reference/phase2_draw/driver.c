int main(void) {
    int32_t a[16];
    R_InitTranslationTables();
    while (scanf("%d", &a[0]) == 1) {
        for (int i=1;i<16;i++) if (scanf("%d", &a[i]) != 1) return 3;
        for (int i=0;i<64000;i++) { screen0[i]=(i*13+17)&255; screen1[i]=(i*29+9)&255; }
        for (int i=0;i<8192;i++) source[i]=(i*37+19)&255;
        for (int m=0;m<34;m++) for(int i=0;i<256;i++) colors[m*256+i]=(m*11+i*7+3)&255;
        viewheight=a[2]; centery=a[15]; fuzzpos=a[14]; R_InitBuffer(a[1],a[2]);
        dc_x=a[3]; dc_yl=a[4]; dc_yh=a[5]; dc_iscale=a[6]; dc_texturemid=a[7];
        dc_source=source+a[8]; dc_colormap=colors; dc_translation=translationtables+256;
        ds_y=a[3]; ds_x1=a[4]; ds_x2=a[5]; ds_xfrac=a[9]; ds_yfrac=a[10];
        ds_xstep=a[11]; ds_ystep=a[12]; ds_source=source; ds_colormap=colors;
        switch(a[0]) {
            case 0: R_DrawColumn(); break;
            case 1: R_DrawColumnLow(); break;
            case 2: R_DrawTranslatedColumn(); break;
            case 3: R_DrawFuzzColumn(); break;
            case 4: R_DrawSpan(); break;
            case 5: R_DrawSpanLow(); break;
            case 6: R_VideoErase(a[4],a[5]); break;
            case 7: memcpy(screen0,translationtables,768); break;
            case 8: break;
            default: return 4;
        }
        fwrite(screen0,1,64000,stdout);
        int32_t state[8]={dc_x,dc_yl,dc_yh,ds_x1,ds_x2,fuzzpos,viewwindowx,viewwindowy};
        fwrite(state,4,8,stdout);
        for(int i=0;i<a[1];i++) { int32_t x=columnofs[i]; fwrite(&x,4,1,stdout); }
        for(int i=0;i<a[2];i++) { int32_t y=(int32_t)(ylookup[i]-screen0); fwrite(&y,4,1,stdout); }
    }
    return 0;
}
