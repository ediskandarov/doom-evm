// SPDX-License-Identifier: GPL-2.0-only
// Observation-only extension: reuse the committed original-gameplay host unchanged.
static void *post_output;
#define main OriginalGameplayMain
#define R_RenderPlayerView ObservePostRender
#include "host.c"
#undef R_RenderPlayerView
#undef main

void R_RenderPlayerView(player_t *player);
void ObservePostRender(player_t *player) {
    R_RenderPlayerView(player);
    FILE *file = post_output;
    word(file, gametic);
    world_record(file);
}

int main(int argc, char **argv) {
    if (argc != 4 && argc != 5) I_Error("post-render host arguments");
    char path[4096];
    snprintf(path, sizeof(path), "%s/post-render.bin", argv[2]);
    post_output = fopen(path, "wb");
    if (!post_output) I_Error("open post-render output");
    int result = OriginalGameplayMain(argc, argv);
    if (fclose(post_output)) I_Error("close post-render output");
    return result;
}
