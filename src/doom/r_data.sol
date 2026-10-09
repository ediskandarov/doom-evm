// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

// Copyright (C) 1993-1996 by id Software, Inc.
// Modified 2026: explicit LE decoding, index pointers, bounded immutable EVM resource access.
import {ResourceView, TexPatch, Texture, RenderResources, ColumnView} from "./r_data_types.sol";
import {LumpDescriptor} from "../evm/ResourceTypes.sol";
import {Vertex, Sector, Side, Line, Seg, Subsector, Node, MapThing, MapData} from "./r_defs.sol";
import {M_Fixed} from "./m_fixed.sol";
import {W_ZoneCache} from "./w_zone_cache.sol";
import {ZoneConst as ZC} from "./z_zone_types.sol";

/// @custom:source linuxdoom-1.10/r_data.c; named W_* adapters map to w_wad.c.
library R_Data {
    error Bounds();
    error MissingName(bytes8 name);
    error Malformed();
    error UndefinedComposite(uint32 texture, uint32 column, uint32 row);
    uint32 internal constant NULL = type(uint32).max;

    /// @notice Copy only the requested range, including a range crossing code chunks.
    function read(ResourceView memory v, uint32 offset, uint32 length)
        internal
        view
        returns (bytes memory out)
    {
        if (uint256(offset) + length > v.byteLength) revert Bounds();
        out = new bytes(length);
        uint256 copied;
        while (copied < length) {
            uint256 pos = uint256(offset) + copied;
            uint256 chunk = pos / 16384;
            uint256 local = pos % 16384;
            uint256 count = uint256(length) - copied;
            if (count > 16384 - local) count = 16384 - local;
            if (chunk >= v.chunks.length) revert Bounds();
            address source = v.chunks[chunk];
            if (source.code.length < local + count + 1) revert Bounds();
            // extcodecopy writes exactly count bytes within out[0:length], never its header.
            assembly ("memory-safe") { extcodecopy(source, add(add(out, 32), copied), add(local, 1), count) }
            copied += count;
        }
    }

    function W_CacheLumpNum(ResourceView memory v, uint32 lump) internal view returns (bytes memory) {
        if (lump >= v.lumps.length) revert Bounds();
        LumpDescriptor memory d = v.lumps[lump];
        return read(v, d.offset, d.length);
    }

    // W_AddFile uses strncpy(name, raw, 8); W_CheckNumForName uppercases the query only.
    function name8(bytes8 name, bool upper) private pure returns (bytes8 result) {
        uint64 acc;
        bool ended;
        for (uint256 i; i < 8; ++i) {
            uint8 c = uint8(name[i]);
            if (c == 0) ended = true;
            if (ended) c = 0;
            else if (upper && c >= 97 && c <= 122) c -= 32;
            acc = (acc << 8) | c;
        }
        return bytes8(acc);
    }

    function W_CheckNumForName(ResourceView memory v, bytes8 name) internal pure returns (int32) {
        bytes8 query = name8(name, true);
        for (uint256 i = v.lumps.length; i != 0; --i) {
            if (
                v.lumps[i - 1].name == query
                    || (v.lumps[i - 1].name[0] == query[0] && name8(v.lumps[i - 1].name, false) == query)
            ) return int32(uint32(i - 1));
        }
        return -1;
    }

    function W_GetNumForName(ResourceView memory v, bytes8 name) internal pure returns (uint32) {
        int32 n = W_CheckNumForName(v, name);
        if (n < 0) revert MissingName(name);
        return uint32(n);
    }

    function u16(bytes memory b, uint256 p) private pure returns (uint16) {
        if (p + 2 > b.length) revert Bounds();
        return uint16(uint8(b[p])) | uint16(uint8(b[p + 1])) << 8;
    }

    function s16(bytes memory b, uint256 p) private pure returns (int32) {
        return int32(int16(u16(b, p)));
    }

    function fixed16(bytes memory b, uint256 p) private pure returns (int32) {
        return s16(b, p) * 65536;
    }

    function u32(bytes memory b, uint256 p) private pure returns (uint32) {
        return uint32(u16(b, p)) | uint32(u16(b, p + 2)) << 16;
    }

    function b8(bytes memory b, uint256 p) private pure returns (bytes8 result) {
        if (p + 8 > b.length) revert Bounds();
        uint64 n;
        for (uint256 i; i < 8; ++i) {
            n = n << 8 | uint8(b[p + i]);
        }
        return bytes8(n);
    }

    function header(ResourceView memory v, uint32 lump, uint32 length) private view returns (bytes memory) {
        if (lump >= v.lumps.length || v.lumps[lump].length < length) revert Bounds();
        return read(v, v.lumps[lump].offset, length);
    }

    /// @custom:source R_InitTextures, R_InitFlats, R_InitSpriteLumps, R_InitColormaps
    function R_InitData(ResourceView memory v) internal view returns (RenderResources memory r) {
        return initData(v, false);
    }

    /// @notice Same immutable definitions, original lookup deferred until a texture is accessed.
    /// @dev Eager R_InitData validates every lookup before deployment readiness; only timing differs.
    function R_InitDataLazy(ResourceView memory v) internal view returns (RenderResources memory r) {
        return initData(v, true);
    }

    function initData(ResourceView memory v, bool lazy) private view returns (RenderResources memory r) {
        r.source = v;
        r.lumpcache = new bytes[](v.lumps.length);
        bytes memory names = W_CacheLumpNum(v, W_GetNumForName(v, "PNAMES"));
        uint32 np = u32(names, 0);
        if (uint256(np) * 8 + 4 > names.length) revert Malformed();
        uint32[] memory nameIndex = lumpIndex(v);
        int32[] memory lookup = new int32[](np);
        for (uint256 i; i < np; ++i) {
            lookup[i] = findLump(v, nameIndex, b8(names, 4 + i * 8));
        }
        bytes memory t1 = W_CacheLumpNum(v, W_GetNumForName(v, "TEXTURE1"));
        int32 t2num = W_CheckNumForName(v, "TEXTURE2");
        bytes memory t2 = t2num < 0 ? new bytes(0) : W_CacheLumpNum(v, uint32(t2num));
        uint32 n1 = u32(t1, 0);
        uint32 n2 = t2num < 0 ? 0 : u32(t2, 0);
        if (uint256(n1) * 4 + 4 > t1.length || (n2 > 0 && uint256(n2) * 4 + 4 > t2.length)) {
            revert Malformed();
        }
        r.textures = new Texture[](uint256(n1) + n2);
        r.texturetranslation = new uint32[](r.textures.length);
        for (uint256 i; i < r.textures.length; ++i) {
            r.texturetranslation[i] = uint32(i);
            bytes memory data = i < n1 ? t1 : t2;
            uint256 p = u32(data, 4 + (i < n1 ? i : i - n1) * 4);
            Texture memory t = r.textures[i];
            t.name = b8(data, p);
            int32 width = s16(data, p + 12);
            int32 height = s16(data, p + 14);
            int32 count = s16(data, p + 20);
            if (width <= 0 || height <= 0 || count <= 0) revert Malformed();
            t.width = uint16(uint32(width));
            t.height = uint16(uint32(height));
            t.patches = new TexPatch[](uint32(count));
            for (uint256 j; j < uint32(count); ++j) {
                uint256 q = p + 22 + j * 10;
                int32 pi = s16(data, q + 4);
                if (pi < 0 || uint32(pi) >= np || lookup[uint32(pi)] < 0) revert Malformed();
                // Original field order; avoid retaining three decoded constructor values
                // during full gameplay hook-graph code generation.
                TexPatch memory patch = t.patches[j];
                patch.originx = s16(data, q);
                patch.originy = s16(data, q + 2);
                patch.patch = uint32(lookup[uint32(pi)]);
            }
            uint32 power = 1;
            while (power * 2 <= t.width) power *= 2;
            t.widthmask = power - 1;
            if (!lazy) R_GenerateLookup(r, uint32(i));
        }
        r.firstflat = W_GetNumForName(v, "F_START") + 1;
        uint32 end = W_GetNumForName(v, "F_END");
        if (end < r.firstflat) revert Malformed();
        r.numflats = end - r.firstflat;
        r.flattranslation = new uint32[](r.numflats);
        for (uint32 i; i < r.numflats; ++i) {
            r.flattranslation[i] = i;
        }
        r.firstspritelump = W_GetNumForName(v, "S_START") + 1;
        end = W_GetNumForName(v, "S_END");
        if (end < r.firstspritelump) revert Malformed();
        r.numspritelumps = end - r.firstspritelump;
        r.spritewidth = new int32[](r.numspritelumps);
        r.spriteoffset = new int32[](r.numspritelumps);
        r.spritetopoffset = new int32[](r.numspritelumps);
        for (uint32 i; i < r.numspritelumps; ++i) {
            bytes memory h = header(v, r.firstspritelump + i, 8);
            r.spritewidth[i] = fixed16(h, 0);
            r.spriteoffset[i] = fixed16(h, 4);
            r.spritetopoffset[i] = fixed16(h, 6);
        }
        r.colormaps = W_CacheLumpNum(v, W_GetNumForName(v, "COLORMAP"));
    }

    /// @custom:source R_GenerateLookup
    function R_GenerateLookup(RenderResources memory r, uint32 texture) internal view {
        Texture memory t = r.textures[texture];
        t.columnlump = new int32[](t.width);
        t.columnofs = new uint32[](t.width);
        bytes memory count = new bytes(t.width);
        t.compositesize = 0;
        t.compositeReady = false;
        for (uint256 i; i < t.patches.length; ++i) {
            TexPatch memory patch = t.patches[i];
            bytes memory h = header(r.source, patch.patch, 8);
            int32 width = s16(h, 0);
            if (width <= 0) revert Malformed();
            h = header(r.source, patch.patch, 8 + uint32(width) * 4);
            int32 x1 = patch.originx;
            int32 x2 = x1 + width;
            if (x2 > int32(uint32(t.width))) x2 = int32(uint32(t.width));
            for (int32 x = x1 < 0 ? int32(0) : x1; x < x2; ++x) {
                uint32 ux = uint32(x);
                // byte count, signed-short lump and unsigned-short offset are original types.
                unchecked {
                    count[ux] = bytes1(uint8(count[ux]) + 1);
                }
                t.columnlump[ux] = int32(int16(uint16(patch.patch)));
                t.columnofs[ux] = uint16(u32(h, 8 + uint32(x - x1) * 4) + 3);
            }
        }
        for (uint32 x; x < t.width; ++x) {
            // Original prints and leaves partially uninitialized state; reject that domain.
            if (count[x] == 0) revert Malformed();
            if (uint8(count[x]) > 1) {
                t.columnlump[x] = -1;
                t.columnofs[x] = uint16(t.compositesize);
                if (t.compositesize > 0x10000 - uint32(t.height)) revert Malformed();
                t.compositesize += t.height;
            }
        }
    }

    /// @custom:source R_DrawColumnInCache
    /// @dev Deliberately does NOT advance source when a negative origin clips the top.
    function R_DrawColumnInCache(
        bytes memory patch,
        uint32 offset,
        bytes memory cache,
        bytes memory written,
        uint32 base,
        int32 originy,
        uint32 height
    ) internal pure {
        uint256 p = offset;
        while (true) {
            if (p >= patch.length) revert Bounds();
            if (patch[p] == 0xff) break;
            if (p + 4 > patch.length) revert Bounds();
            int32 count = int32(uint32(uint8(patch[p + 1])));
            int32 position = originy + int32(uint32(uint8(patch[p])));
            if (p + uint32(count) + 4 > patch.length) revert Bounds();
            uint256 next = p + uint32(count) + 4;
            if (position < 0) {
                count += position;
                position = 0;
            }
            if (position + count > int32(height)) count = int32(height) - position;
            if (count > 0) {
                uint256 destination = uint256(base) + uint32(position);
                uint256 length = uint32(count);
                if (destination + length > cache.length || destination + length > written.length) {
                    revert Bounds();
                }
                // Exact C memcpy: source starts at post+3 even when clipping a negative origin.
                // Source post bounds checked above; both destination byte ranges checked here.
                // mcopy touches exactly length bytes. Coverage writes complete words only within
                // that same interval and handles the remainder with single-byte writes.
                assembly ("memory-safe") {
                    mcopy(add(add(cache, 32), destination), add(add(patch, 35), p), length)
                    let target := add(add(written, 32), destination)
                    let n := 0
                    for {} iszero(gt(add(n, 32), length)) { n := add(n, 32) } {
                        mstore(
                            add(target, n),
                            0x0101010101010101010101010101010101010101010101010101010101010101
                        )
                    }
                    for {} lt(n, length) { n := add(n, 1) } { mstore8(add(target, n), 1) }
                }
            }
            p = next;
        }
    }

    /// @custom:source R_GenerateComposite
    function R_GenerateComposite(RenderResources memory r, uint32 texture) internal view {
        generateComposite(r, texture, true);
    }

    /// @dev Rebuilding ephemeral bytes for an existing native cache owner is parsing,
    /// not another original Z_Malloc or W_CacheLumpNum call.
    function generateComposite(RenderResources memory r, uint32 texture, bool nativeCall) private view {
        Texture memory t = r.textures[texture];
        if (t.columnlump.length == 0) R_GenerateLookup(r, texture);
        uint32 nativeBlock;
        if (nativeCall) {
            nativeBlock = W_ZoneCache.allocateComposite(r.nativeZone, r.source, texture, t.compositesize);
        }
        bytes memory composite = new bytes(t.compositesize);
        bytes memory written = new bytes(t.compositesize);
        for (uint256 i; i < t.patches.length; ++i) {
            TexPatch memory patch = t.patches[i];
            bytes memory data = nativeCall ? cacheLump(r, patch.patch, ZC.PU_CACHE) : loadLump(r, patch.patch);
            int32 x1 = patch.originx;
            int32 x2 = x1 + s16(data, 0);
            if (x2 > int32(uint32(t.width))) x2 = int32(uint32(t.width));
            for (int32 x = x1 < 0 ? int32(0) : x1; x < x2; ++x) {
                if (t.columnlump[uint32(x)] >= 0) continue;
                R_DrawColumnInCache(
                    data,
                    u32(data, 8 + uint32(x - x1) * 4),
                    composite,
                    written,
                    t.columnofs[uint32(x)],
                    patch.originy,
                    t.height
                );
            }
        }
        // C's zone allocation leaves holes indeterminate. Do not silently turn holes black.
        for (uint32 x; x < t.width; ++x) {
            if (t.columnlump[x] < 0) {
                uint32 y;
                while (uint256(y) + 32 <= t.height) {
                    uint256 offset = uint256(t.columnofs[x]) + y;
                    if (offset + 32 > written.length) revert Bounds();
                    uint256 word;
                    // A full 32-byte read entirely inside the coverage bytes, never allocation padding.
                    assembly ("memory-safe") { word := mload(add(add(written, 32), offset)) }
                    if (word != 0x0101010101010101010101010101010101010101010101010101010101010101) break;
                    y += 32;
                }
                for (; y < t.height; ++y) {
                    if (written[t.columnofs[x] + y] == 0) revert UndefinedComposite(texture, x, y);
                }
            }
        }
        t.composite = composite;
        t.compositeReady = true;
        if (nativeCall) W_ZoneCache.changeTag(r.nativeZone, nativeBlock, ZC.PU_CACHE);
    }

    /// @custom:source R_GetColumn
    function R_GetColumn(RenderResources memory r, uint32 texture, int32 column)
        internal
        view
        returns (ColumnView memory v)
    {
        if (texture >= r.textures.length) revert Bounds();
        Texture memory t = r.textures[texture];
        if (t.columnlump.length == 0) R_GenerateLookup(r, texture);
        uint32 col = uint32(column) & t.widthmask;
        int32 lump = t.columnlump[col];
        uint32 offset = t.columnofs[col];
        if (lump > 0) {
            v.data = cacheLump(r, uint32(lump), ZC.PU_CACHE);
            r.currentColumnZoneBlock = W_ZoneCache.ownerBlock(r.nativeZone, uint32(lump));
            v.offset = offset;
            // An empty last column is just the 0xff terminator. The original returned
            // pixel pointer may be two bytes past the lump; masked callers subtract three.
            // No byte is read here. Preserve that virtual pointer while retaining its prefix.
            if (offset > v.data.length && (offset < 3 || offset - 3 >= v.data.length)) revert Bounds();
            return v;
        }
        if (r.nativeZone.byteLength != 0) {
            if (W_ZoneCache.compositeBlock(r.nativeZone, r.source, texture) == ZC.NULL) {
                R_GenerateComposite(r, texture);
            } else if (!t.compositeReady) {
                generateComposite(r, texture, false);
            }
        } else if (!t.compositeReady) {
            R_GenerateComposite(r, texture);
        }
        v.data = t.composite;
        r.currentColumnZoneBlock = W_ZoneCache.compositeBlock(r.nativeZone, r.source, texture);
        v.offset = offset;
        if (offset >= v.data.length) revert Bounds();
    }

    function R_CheckTextureNumForName(RenderResources memory r, bytes8 name) internal pure returns (int32) {
        if (name[0] == "-") return 0;
        bytes8 query = name8(name, true);
        for (uint256 i; i < r.textures.length; ++i) {
            bytes8 candidate = r.textures[i].name;
            if (
                candidate == query
                    || ((uint8(candidate[0]) & 0xdf) == (uint8(query[0]) & 0xdf)
                        && name8(candidate, true) == query)
            ) return int32(uint32(i));
        }
        return -1;
    }

    function R_TextureNumForName(RenderResources memory r, bytes8 name) internal pure returns (uint32) {
        int32 n = R_CheckTextureNumForName(r, name);
        if (n < 0) revert MissingName(name);
        return uint32(n);
    }

    function R_FlatNumForName(RenderResources memory r, bytes8 name) internal pure returns (uint32) {
        uint32 n = W_GetNumForName(r.source, name);
        // C returns a signed out-of-marker-range number; unsafe use is rejected at access.
        unchecked {
            return n - r.firstflat;
        }
    }

    function R_GetFlat(RenderResources memory r, uint32 flat) internal view returns (bytes memory) {
        if (flat >= r.numflats) revert Bounds();
        return cacheLump(r, r.firstflat + flat, ZC.PU_STATIC);
    }

    /// @notice EVM pointer adapter for colormaps + index*256, reused across draw calls.
    function R_GetColormap(RenderResources memory r, uint32 index) internal pure returns (bytes memory data) {
        uint256 count = r.colormaps.length / 256;
        if (index >= count) revert Bounds();
        if (r.colormapcache.length == 0) r.colormapcache = new bytes[](count);
        if (r.colormapcache.length != count) revert Malformed();
        data = r.colormapcache[index];
        if (data.length == 0) {
            data = new bytes(256);
            bytes memory maps = r.colormaps;
            uint256 offset = uint256(index) * 256;
            // Checked index proves the full source slice exists; destination is a fresh 256-byte array.
            assembly ("memory-safe") { mcopy(add(data, 32), add(add(maps, 32), offset), 256) }
            r.colormapcache[index] = data;
        }
    }

    function releaseFlat(RenderResources memory r, uint32 flat) internal pure {
        if (r.nativeZone.byteLength != 0) {
            W_ZoneCache.changeTag(
                r.nativeZone, W_ZoneCache.ownerBlock(r.nativeZone, r.firstflat + flat), ZC.PU_CACHE
            );
        }
    }

    function cacheLump(RenderResources memory r, uint32 lump, uint8 tag)
        internal
        view
        returns (bytes memory data)
    {
        W_ZoneCache.cacheLump(r.nativeZone, r.source, lump, tag);
        return loadLump(r, lump);
    }

    function loadLump(RenderResources memory r, uint32 lump) private view returns (bytes memory data) {
        // Synthetic tests may construct RenderResources directly; initialize their cache on demand.
        if (r.lumpcache.length == 0) r.lumpcache = new bytes[](r.source.lumps.length);
        if (lump >= r.lumpcache.length) revert Bounds();
        data = r.lumpcache[lump];
        if (data.length == 0) {
            data = W_CacheLumpNum(r.source, lump);
            r.lumpcache[lump] = data;
        }
    }

    // Exact ephemeral hash indexes replace repeated linear scans without changing precedence.
    // Slots hold index+1; collision resolution compares the complete normalized eight-byte key.
    function hashName(bytes8 name, uint256 mask) private pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(name))) & mask;
    }

    function lumpIndex(ResourceView memory v) private pure returns (uint32[] memory table) {
        uint256 size = 1;
        while (size < v.lumps.length * 2) size *= 2;
        table = new uint32[](size);
        for (uint256 i; i < v.lumps.length; ++i) {
            bytes8 key = name8(v.lumps[i].name, false);
            uint256 slot = hashName(key, size - 1);
            while (table[slot] != 0 && name8(v.lumps[table[slot] - 1].name, false) != key) {
                slot = (slot + 1) & (size - 1);
            }
            table[slot] = uint32(i + 1); // Original W_CheckNumForName chooses the last lump.
        }
    }

    function findLump(ResourceView memory v, uint32[] memory table, bytes8 name)
        private
        pure
        returns (int32)
    {
        bytes8 key = name8(name, true);
        uint256 slot = hashName(key, table.length - 1);
        while (table[slot] != 0) {
            uint32 i = table[slot] - 1;
            if (name8(v.lumps[i].name, false) == key) return int32(i);
            slot = (slot + 1) & (table.length - 1);
        }
        return -1;
    }

    function textureIndex(RenderResources memory r) private pure returns (uint32[] memory table) {
        uint256 size = 1;
        while (size < r.textures.length * 2) size *= 2;
        table = new uint32[](size);
        for (uint256 j = r.textures.length; j > 0; --j) {
            uint256 i = j - 1;
            bytes8 key = name8(r.textures[i].name, true);
            uint256 slot = hashName(key, size - 1);
            while (table[slot] != 0 && name8(r.textures[table[slot] - 1].name, true) != key) {
                slot = (slot + 1) & (size - 1);
            }
            table[slot] = uint32(i + 1); // First texture takes precedence, opposite to WAD lookup.
        }
    }

    function findTexture(RenderResources memory r, uint32[] memory table, bytes8 name)
        private
        pure
        returns (uint32)
    {
        if (name[0] == "-") return 0;
        bytes8 key = name8(name, true);
        uint256 slot = hashName(key, table.length - 1);
        while (table[slot] != 0) {
            uint32 i = table[slot] - 1;
            if (name8(r.textures[i].name, true) == key) {
                // p_setup stores this result in side_t signed-short texture fields.
                if (i > 32767) revert Bounds();
                return i;
            }
            slot = (slot + 1) & (table.length - 1);
        }
        revert MissingName(name);
    }

    function findFlat(RenderResources memory r, uint32[] memory table, bytes8 name)
        private
        pure
        returns (uint32)
    {
        int32 n = findLump(r.source, table, name);
        if (n < 0) revert MissingName(name);
        // p_setup stores this result in sector_t signed-short picture fields.
        if (uint32(n) < r.firstflat || uint32(n) - r.firstflat > 32767) revert Bounds();
        return uint32(n) - r.firstflat;
    }

    function records(bytes memory data, uint256 stride) private pure returns (uint256) {
        if (data.length % stride != 0) revert Malformed();
        return data.length / stride;
    }

    function index16(bytes memory data, uint256 position, uint256 limit, bool nullable)
        private
        pure
        returns (uint32)
    {
        int32 n = s16(data, position);
        if (nullable && n == -1) return NULL;
        if (n < 0 || uint32(n) >= limit) revert Bounds();
        return uint32(n);
    }

    /// @dev Call-local line-loader working aliases, never persisted or supplied by a host.
    /// Reads/writes keep original order; grouping aliases avoids full-hook-graph stack pressure.
    struct MapLineWork {
        uint256 offset;
        Line line;
        Vertex first;
        Vertex second;
    }

    /// @notice Static p_setup.c adapter: P_Load* order and P_GroupLines subsector binding.
    /// @dev No thinkers, gameplay spawning, BLOCKMAP collision state, or sector line lists yet.
    function R_LoadMap(RenderResources memory r, bytes8 mapname) internal view returns (MapData memory m) {
        uint32 base = W_GetNumForName(r.source, mapname);
        uint32[] memory names = lumpIndex(r.source);
        uint32[] memory textures = textureIndex(r);
        bytes memory b = W_CacheLumpNum(r.source, base + 4);
        m.vertexes = new Vertex[](records(b, 4));
        for (uint256 i; i < m.vertexes.length; ++i) {
            m.vertexes[i] = Vertex(fixed16(b, i * 4), fixed16(b, i * 4 + 2));
        }
        b = W_CacheLumpNum(r.source, base + 8);
        m.sectors = new Sector[](records(b, 26));
        for (uint256 i; i < m.sectors.length; ++i) {
            uint256 p = i * 26;
            m.sectors[i] = Sector(
                fixed16(b, p),
                fixed16(b, p + 2),
                findFlat(r, names, b8(b, p + 4)),
                findFlat(r, names, b8(b, p + 12)),
                int16(s16(b, p + 20))
            );
        }
        b = W_CacheLumpNum(r.source, base + 3);
        m.sides = new Side[](records(b, 30));
        for (uint256 i; i < m.sides.length; ++i) {
            uint256 p = i * 30;
            m.sides[i] = Side(
                fixed16(b, p),
                fixed16(b, p + 2),
                findTexture(r, textures, b8(b, p + 4)),
                findTexture(r, textures, b8(b, p + 12)),
                findTexture(r, textures, b8(b, p + 20)),
                index16(b, p + 28, m.sectors.length, false)
            );
        }
        b = W_CacheLumpNum(r.source, base + 2);
        m.lines = new Line[](records(b, 14));
        MapLineWork memory work;
        for (uint256 i; i < m.lines.length; ++i) {
            work.offset = i * 14;
            work.line = m.lines[i];
            work.line.v1 = index16(b, work.offset, m.vertexes.length, false);
            work.line.v2 = index16(b, work.offset + 2, m.vertexes.length, false);
            work.first = m.vertexes[work.line.v1];
            work.second = m.vertexes[work.line.v2];
            unchecked {
                work.line.dx = work.second.x - work.first.x;
                work.line.dy = work.second.y - work.first.y;
            }
            work.line.flags = u16(b, work.offset + 4);
            work.line.special = int16(s16(b, work.offset + 6));
            work.line.tag = int16(s16(b, work.offset + 8));
            work.line.slopetype = work.line.dx == 0
                ? 1
                : work.line.dy == 0 ? 0 : M_Fixed.FixedDiv(work.line.dy, work.line.dx) > 0 ? 2 : 3;
            work.line.bbox[0] = work.first.y > work.second.y ? work.first.y : work.second.y;
            work.line.bbox[1] = work.first.y < work.second.y ? work.first.y : work.second.y;
            work.line.bbox[2] = work.first.x < work.second.x ? work.first.x : work.second.x;
            work.line.bbox[3] = work.first.x > work.second.x ? work.first.x : work.second.x;
            work.line.sidenum[0] = index16(b, work.offset + 10, m.sides.length, true);
            work.line.sidenum[1] = index16(b, work.offset + 12, m.sides.length, true);
            work.line.frontsector = work.line.sidenum[0] == NULL ? NULL : m.sides[work.line.sidenum[0]].sector;
            work.line.backsector = work.line.sidenum[1] == NULL ? NULL : m.sides[work.line.sidenum[1]].sector;
        }
        b = W_CacheLumpNum(r.source, base + 5);
        m.segs = new Seg[](records(b, 12));
        for (uint256 i; i < m.segs.length; ++i) {
            uint256 p = i * 12;
            Seg memory s = m.segs[i];
            s.v1 = index16(b, p, m.vertexes.length, false);
            s.v2 = index16(b, p + 2, m.vertexes.length, false);
            s.angle = uint32(fixed16(b, p + 4));
            s.linedef = index16(b, p + 6, m.lines.length, false);
            s.offset = fixed16(b, p + 10);
            uint32 side = index16(b, p + 8, 2, false);
            Line memory l = m.lines[s.linedef];
            s.sidedef = l.sidenum[side];
            if (s.sidedef == NULL) revert Bounds();
            s.frontsector = m.sides[s.sidedef].sector;
            s.backsector = NULL;
            if (l.flags & 4 != 0) {
                if (l.sidenum[side ^ 1] == NULL) revert Bounds();
                s.backsector = m.sides[l.sidenum[side ^ 1]].sector;
            }
        }
        b = W_CacheLumpNum(r.source, base + 6);
        m.subsectors = new Subsector[](records(b, 4));
        for (uint256 i; i < m.subsectors.length; ++i) {
            uint256 p = i * 4;
            int32 signedCount = s16(b, p);
            uint32 first = index16(b, p + 2, m.segs.length, false);
            // Both disk mapsubsector_t and runtime subsector_t fields are signed short.
            // Reject negative counts before exposing them as bounded runtime indexes.
            if (signedCount < 0) revert Bounds();
            uint32 count = uint32(signedCount);
            if (uint256(first) + count > m.segs.length) revert Bounds();
            m.subsectors[i] = Subsector(m.sides[m.segs[first].sidedef].sector, count, first);
        }
        b = W_CacheLumpNum(r.source, base + 7);
        m.nodes = new Node[](records(b, 28));
        if (m.nodes.length > 32768 || (m.nodes.length == 0 && m.subsectors.length != 1)) revert Malformed();
        for (uint256 i; i < m.nodes.length; ++i) {
            uint256 p = i * 28;
            Node memory n = m.nodes[i];
            n.x = fixed16(b, p);
            n.y = fixed16(b, p + 2);
            n.dx = fixed16(b, p + 4);
            n.dy = fixed16(b, p + 6);
            for (uint256 child; child < 2; ++child) {
                for (uint256 k; k < 4; ++k) {
                    n.bbox[child][k] = fixed16(b, p + 8 + child * 8 + k * 2);
                }
                n.children[child] = u16(b, p + 24 + child * 2);
                uint16 c = n.children[child];
                if (c & 0x8000 != 0
                        ? uint256(c & 0x7fff) >= m.subsectors.length
                        : uint256(c) >= m.nodes.length) revert Bounds();
            }
        }
        b = W_CacheLumpNum(r.source, base + 1);
        m.things = new MapThing[](records(b, 10));
        for (uint256 i; i < m.things.length; ++i) {
            uint256 p = i * 10;
            m.things[i] = MapThing(
                int16(s16(b, p)),
                int16(s16(b, p + 2)),
                int16(s16(b, p + 4)),
                int16(s16(b, p + 6)),
                int16(s16(b, p + 8))
            );
        }
    }
}
