// SPDX-License-Identifier: GPL-2.0-only
// Generated committed-host copy has only added observer stages, no original decisions.
#define main OriginalGameplayMain
#include "original-host.c"
#undef main
FILE *zone_events,*zone_stages,*zone_sprites;
int main(int argc,char **argv) {
    if(argc!=4 && argc!=5)I_Error("zone lifecycle args");
    char path[4096];
#define OPEN(field,name) snprintf(path,sizeof(path),"%s/" name,argv[2]);field=fopen(path,"wb");if(!field)I_Error("open zone observation");
    OPEN(zone_events,"zone-events.jsonl");OPEN(zone_stages,"zone-stages.jsonl");OPEN(zone_sprites,"zone-sprites.jsonl");
    int result=OriginalGameplayMain(argc,argv);
    ZoneStage("final");
    fclose(zone_events);fclose(zone_stages);fclose(zone_sprites);return result;
}
