/* SPDX-License-Identifier: GPL-2.0-only
 * Resource emission only; no spawning, ticking, rendering or transitions.
 * Earlier driver functions are reused with a parameterized map marker. */
static void path(char *out, const char *directory, const char *map, const char *suffix) {
    if (snprintf(out, 4096, "%s/%s.%s", directory, map, suffix) >= 4096) abort();
}
int main(int argc, char **argv) {
    if (argc != 3) return 1;
    loadwad(argv[1]); textures_adapter();
    char out[4096]; path(out, argv[2], "shared", "bin"); emit_resources(out);
    path(out, argv[2], "shared", "indices.bin"); FILE *shared = fopen(out, "wb"); if (!shared) abort();
    wr32(shared, numtextures);
    for (int i = 0; i < numtextures; ++i) {
        texture_t *t = textures[i]; fwrite(t->name, 1, 8, shared); wr32(shared, t->patchcount);
        for (int p = 0; p < t->patchcount; ++p) wr32(shared, t->patches[p].patch);
    }
    wr32(shared, firstflat); wr32(shared, numflats); wr32(shared, firstspritelump); wr32(shared, numspritelumps);
    fclose(shared);
    for (int m = 1; m <= 9; ++m) {
        char map[9]; snprintf(map, sizeof(map), "E1M%d", m); selected_map = map;
        int base = W_GetNumForName(map);
        path(out, argv[2], map, "map.bin"); emit_map(out);
        path(out, argv[2], map, "things.bin"); FILE *f = fopen(out, "wb"); if (!f) abort();
        mapthing_t *things = W_CacheLumpNum(base+1, PU_STATIC);
        int count = W_LumpLength(base+1)/sizeof(mapthing_t); wr32(f, count);
        for (int i = 0; i < count; ++i) {
            wr32(f, SHORT(things[i].x)); wr32(f, SHORT(things[i].y)); wr32(f, SHORT(things[i].angle));
            wr32(f, SHORT(things[i].type)); wr32(f, SHORT(things[i].options));
        }
        fclose(f);
        P_LoadBlockMap(base+10);
        path(out, argv[2], map, "blockmap.bin"); f = fopen(out, "wb"); if (!f) abort();
        wr32(f, bmaporgx); wr32(f, bmaporgy); wr32(f, bmapwidth); wr32(f, bmapheight);
        for (int i = 0; i < W_LumpLength(base+10)/2; ++i) wr32(f, blockmaplump[i]);
        fclose(f);
        path(out, argv[2], map, "raw.bin"); f = fopen(out, "wb"); if (!f) abort();
        wr32(f, base);
        for (int i = 1; i <= 10; ++i) {
            int id = base+i, size = W_LumpLength(id);
            wr32(f, id); wr32(f, size); fwrite(W_CacheLumpNum(id, PU_LEVEL), 1, size, f);
        }
        fclose(f);
    }
    return 0;
}
