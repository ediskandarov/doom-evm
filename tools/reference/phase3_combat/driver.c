/* SPDX-License-Identifier: GPL-2.0-only */
static void word(int32_t value) {
    uint32_t u = (uint32_t)value;
    for (int s = 24; s >= 0; s -= 8) putchar((u >> s) & 255);
}
static uint32_t messagehash(const char *message) {
    if (!message) return 0;
    uint32_t hash = 2166136261u;
    while (*message) hash = (hash ^ (unsigned char)*message++) * 16777619u;
    return hash;
}
static void run(int32_t a[16]) {
    memset(players, 0, sizeof(players)); memset(actors, 0, sizeof(actors));
    memset(&sector, 0, sizeof(sector)); memset(&subsector, 0, sizeof(subsector));
    sector.special = a[0] == 7 ? a[1] : 0; subsector.sector = &sector;
    player_t *p = &players[0]; mobj_t *mo = &actors[0], *special = &actors[1];
    gameskill = a[3]; gamemode = a[4]; netgame = a[5]; deathmatch = a[6];
    p->mo = mo; p->readyweapon = a[7]; p->pendingweapon = wp_nochange;
    p->health = a[10]; p->armorpoints = a[11]; p->armortype = a[12];
    for (int i = 0; i < NUMWEAPONS; ++i) p->weaponowned[i] = (a[8] >> i) & 1;
    for (int i = 0; i < NUMAMMO; ++i) { p->ammo[i] = a[9]; p->maxammo[i] = maxammo[i]; }
    for (int i = 0; i < NUMPOWERS; ++i) p->powers[i] = (a[13] >> i) & 1;
    for (int i = 0; i < NUMCARDS; ++i) p->cards[i] = (a[14] >> i) & 1;
    for (int i = 0; i < NUMPSPRITES; ++i) p->psprites[i].state = NULL;
    mo->player = p; mo->type = MT_PLAYER; mo->info = &mobjinfo[MT_PLAYER];
    mo->health = p->health; mo->flags = MF_SOLID | MF_SHOOTABLE;
    mo->height = 56 * FRACUNIT; mo->subsector = &subsector;
    mo->state = &states[S_PLAY]; mo->tics = states[S_PLAY].tics;
    mo->reactiontime = 9;
    if (a[0] == 9) {
        mo->type = a[1]; mo->info = &mobjinfo[mo->type]; mo->health = a[2];
        mo->player = NULL; mo->flags |= MF_COUNTKILL | MF_FLOAT | MF_NOGRAVITY | MF_SKULLFLY;
        mo->height = mo->info->height;
    }
    special->sprite = a[1]; special->flags = MF_SPECIAL | MF_COUNTITEM | (a[2] ? MF_DROPPED : 0);
    removed = 0; spawnedtype = -1; prndindex = a[15];
    int result = 0;
    switch (a[0]) {
      case 0: result = P_GiveAmmo(p, a[1], a[2]); break;
      case 1: result = P_GiveWeapon(p, a[1], a[2]); break;
      case 2: result = P_GiveBody(p, a[2]); break;
      case 3: result = P_GiveArmor(p, a[2]); break;
      case 4: P_GiveCard(p, a[1]); break;
      case 5: result = P_GivePower(p, a[1]); break;
      case 6: P_TouchSpecialThing(special, mo); break;
      case 7: P_DamageMobj(mo, NULL, NULL, a[2]); break;
      case 8: result = P_CheckAmmo(p); break;
      case 9: P_KillMobj(NULL, mo); break;
      default: abort();
    }
    for (int i = 0; i < 16; ++i) word(a[i]);
    word(result); word(p->pendingweapon); word(p->health); word(p->armorpoints); word(p->armortype);
    uint32_t weapons = 0, cards = 0;
    for (int i = 0; i < NUMWEAPONS; ++i) weapons |= (p->weaponowned[i] != 0) << i;
    for (int i = 0; i < NUMCARDS; ++i) cards |= (p->cards[i] != 0) << i;
    word(weapons); word(p->backpack); word(p->bonuscount); word(p->itemcount); word(p->damagecount); word(p->playerstate);
    for (int i = 0; i < NUMAMMO; ++i) word(p->ammo[i]);
    for (int i = 0; i < NUMAMMO; ++i) word(p->maxammo[i]);
    for (int i = 0; i < NUMPOWERS; ++i) word(p->powers[i]);
    word(cards); word(mo->health); word(mo->flags);
    word(p->psprites[0].state ? p->psprites[0].state - states : -1);
    word(mo->state ? mo->state - states : -1); word(mo->tics);
    word(mo->reactiontime); word(mo->threshold); word(prndindex);
    word(removed); word(spawnedtype); word(messagehash(p->message));
    word(p->killcount);
    for (int i = 0; i < MAXPLAYERS; ++i) word(p->frags[i]);
}
int main(void) {
    int32_t a[16];
    while (scanf("%d", &a[0]) == 1) {
        for (int i = 1; i < 16; ++i) if (scanf("%d", &a[i]) != 1) abort();
        run(a);
    }
    return ferror(stdout) ? 1 : 0;
}
