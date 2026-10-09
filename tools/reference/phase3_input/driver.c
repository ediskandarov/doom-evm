/* SPDX-License-Identifier: GPL-2.0-only */
static void word(int32_t v) {
    uint32_t u = (uint32_t)v;
    for (int shift = 24; shift >= 0; shift -= 8) putchar((int)((u >> shift) & 255));
}
static void runmask(uint32_t mask) {
    memset(gamekeydown, 0, sizeof(gamekeydown));
    for (unsigned bit = 0; bit < 10; ++bit) gamekeydown[bit + 1] = (mask >> bit) & 1;
    unsigned request = (mask >> 10) & 15;
    if (request) gamekeydown['0' + request] = true;
    int before = turnheld;
    ticcmd_t cmd;
    G_BuildTiccmd(&cmd);
    if (cmd.consistancy || cmd.chatchar) abort();
    word((int32_t)mask); word(before); word(turnheld);
    word(cmd.forwardmove); word(cmd.sidemove); word(cmd.angleturn); word(cmd.buttons);
}
static void reset(void) {
    dclicktime = dclickstate = dclicks = dclicktime2 = dclickstate2 = dclicks2 = 0;
}
int main(void) {
    const int states[] = {0, 4, 5, 20};
    const uint32_t sequence[] = {
        16,16,16,16,16,16,16,16,0,288,288,288,288,288,288,288,288,0,
        544,544,544,544,32,32,32,48,48,48,3,1023,0,16,
        1024,2048,3072,4096,5120,6144,7168,8192,9216,0,
        3072|128,3072|128,1024|64,1024|64,0
    };
    unsigned sequence_count = sizeof(sequence) / sizeof(sequence[0]);
    word(4 * 10 * 1024 + (int32_t)sequence_count);
    for (unsigned s = 0; s < 4; ++s) {
        for (unsigned request = 0; request <= 9; ++request) {
            for (unsigned mask = 0; mask < 1024; ++mask) {
                reset(); turnheld = states[s]; runmask(mask | (request << 10));
            }
        }
    }
    reset(); turnheld = 0;
    for (unsigned i = 0; i < sequence_count; ++i) runmask(sequence[i]);
    return ferror(stdout) ? 1 : 0;
}
