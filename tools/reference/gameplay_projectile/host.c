// SPDX-License-Identifier: GPL-2.0-only
// Test-only controlled original-object setup; gameplay and renderer remain original.
static void *projectile_post_output;
static void *projectile_damage_output;
static int projectile_radius_depth;
#define main OriginalGameplayMain
#define P_SetupLevel ProjectileSetup
#define R_RenderPlayerView ProjectilePostRender
#include "../gameplay/host.c"
#undef R_RenderPlayerView
#undef P_SetupLevel
#undef main

void P_SetupLevel(int episode, int map, int playermask, skill_t skill);
void R_RenderPlayerView(player_t *player);

static void ProjectileDamageRecord(int kind, mobj_t *target, mobj_t *inflictor, mobj_t *source, int damage) {
    FILE *file = projectile_damage_output;
    word(file, gametic+1); word(file, kind);
    word(file, identity(target)); word(file, identity(inflictor)); word(file, identity(source));
    word(file, damage); word(file, projectile_radius_depth);
    word(file, target ? target->health:0); word(file, target ? target->type:-1);
    word(file, inflictor ? inflictor->type:-1); word(file, target ? target->flags:0);
}

void ProjectileDamageObserved(void *target, void *inflictor, void *source, int damage) {
    ProjectileDamageRecord(3, target, inflictor, source, damage);
}

void ProjectileRadiusObserved(void *spot, void *source, int damage, int entering) {
    if (entering) ++projectile_radius_depth;
    ProjectileDamageRecord(entering ? 1:2, spot, spot, source, damage);
    if (!entering) --projectile_radius_depth;
}

void ProjectileSetup(int episode, int map, int playermask, skill_t skill) {
    P_SetupLevel(episode, map, playermask, skill);
    mobj_t *player = players[0].mo;
    mobj_t *enemy = P_SpawnMobj(player->x + 64*FRACUNIT, player->y, ONFLOORZ, MT_POSSESSED);
    if (!P_CheckPosition(enemy, enemy->x, enemy->y)) I_Error("Projectile enemy overlaps geometry/object");
    enemy->angle = ANG180;
    enemy->target = player;
    P_SetMobjState(enemy, enemy->info->seestate);
    player->angle = 0;
    players[0].armorpoints = 200;
    players[0].armortype = 2;
    players[0].weaponowned[wp_missile] = true;
    players[0].readyweapon = wp_missile;
    players[0].pendingweapon = wp_nochange;
    players[0].ammo[am_misl] = 6;
    P_SetupPsprites(players);
}

void ProjectilePostRender(player_t *player) {
    R_RenderPlayerView(player);
    FILE *file = projectile_post_output;
    word(file, gametic);
    world_record(file);
}

int main(int argc, char **argv) {
    if (argc != 4 && argc != 5) I_Error("Projectile host arguments");
    if (argc == 5 && strcmp(argv[4], "ordinary")) I_Error("Projectile host requires ordinary setup argument");
    char path[4096];
    snprintf(path, sizeof(path), "%s/post-render.bin", argv[2]);
    projectile_post_output = fopen(path, "wb");
    if (!projectile_post_output) I_Error("open projectile post-render observations");
    snprintf(path, sizeof(path), "%s/damage-timeline.bin", argv[2]);
    projectile_damage_output = fopen(path, "wb");
    if (!projectile_damage_output) I_Error("open projectile damage observations");
    int result = OriginalGameplayMain(argc, argv);
    char kinds[256];
    int length = snprintf(kinds, sizeof(kinds), "{\"rocketType\":%d,\"rocketState\":%d,\"explosionState\":%d}\n", MT_ROCKET, S_ROCKET, S_EXPLODE1);
    writefile(argv[2], "kinds.json", kinds, length);
    if (fclose(projectile_post_output)) I_Error("close projectile post-render observations");
    if (fclose(projectile_damage_output)) I_Error("close projectile damage observations");
    if (projectile_radius_depth) I_Error("unbalanced projectile radius observation");
    return result;
}
