// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {RenderState, DrawColumn, DrawSpan} from "../../src/doom/r_state.sol";
import {R_Draw} from "../../src/doom/r_draw.sol";
import {DrawVectors} from "../fixtures/phase2_draw/DrawVectors.sol";

contract RDrawTest {
    event log_named_uint(string key, uint256 value);

    function _i(bytes memory packed, uint256 p) private pure returns (int32 value) {
        assembly ("memory-safe") { value := signextend(3, shr(224, mload(add(add(packed, 32), p)))) }
    }

    function _digest(bytes memory packed, uint256 p) private pure returns (bytes32 value) {
        assembly ("memory-safe") { value := mload(add(add(packed, 32), p)) }
    }

    function _pattern(uint256 length, uint256 mul, uint256 addend) private pure returns (bytes memory data) {
        data = new bytes(length);
        bytes memory pattern = new bytes(256);
        for (uint256 i; i < 256; ++i) {
            pattern[i] = bytes1(uint8(i * mul + addend));
        }
        for (uint256 i; i < length; i += 256) {
            uint256 n = length - i < 256 ? length - i : 256;
            // Both buffers allocated by Solidity; copy exactly n in-bounds bytes, no overread/padding writes.
            assembly ("memory-safe") { mcopy(add(add(data, 32), i), add(pattern, 32), n) }
        }
    }

    function _state(uint32 width, uint32 height) private pure returns (RenderState memory rs) {
        rs.framebuffer = _pattern(64000, 13, 17);
        rs.height = uint16(height);
        rs.width = uint16(width);
        R_Draw.R_InitBuffer(rs, width, height);
    }

    function _lookups(RenderState memory rs) private pure returns (bytes32) {
        bytes memory data = new bytes(4 * (rs.columnofs.length + rs.ylookup.length));
        for (uint256 i; i < data.length / 4; ++i) {
            uint32 v = i < rs.columnofs.length ? rs.columnofs[i] : rs.ylookup[i - rs.columnofs.length];
            for (uint256 j; j < 4; ++j) {
                data[i * 4 + j] = bytes1(uint8(v >> (8 * j)));
            }
        }
        return sha256(data);
    }

    function _apply(RenderState memory rs, DrawColumn memory dc, DrawSpan memory ds, uint256 op)
        private
        pure
    {
        if (op == 0) {
            R_Draw.R_DrawColumn(rs, dc);
        } else if (op == 1) {
            R_Draw.R_DrawColumnLow(rs, dc);
        } else if (op == 2) {
            R_Draw.R_DrawTranslatedColumn(rs, dc);
        } else if (op == 3) {
            bytes memory maps = new bytes(34 * 256);
            for (uint256 m; m < 34; ++m) {
                for (uint256 i; i < 256; ++i) {
                    maps[m * 256 + i] = bytes1(uint8(m * 11 + i * 7 + 3));
                }
            }
            R_Draw.R_DrawFuzzColumn(rs, dc, maps);
        } else if (op == 4) {
            R_Draw.R_DrawSpan(rs, ds);
        } else if (op == 5) {
            R_Draw.R_DrawSpanLow(rs, ds);
        } else if (op == 6) {
            R_Draw.R_VideoErase(rs, _pattern(64000, 29, 9), uint32(dc.yl), uint32(dc.yh));
        } else if (op == 7) {
            bytes memory tables = R_Draw.R_InitTranslationTables();
            for (uint256 i; i < 768; ++i) {
                rs.framebuffer[i] = tables[i];
            }
        }
    }

    function _case(bytes memory vectors, uint256 p) private pure {
        int32[16] memory a;
        for (uint256 i; i < 16; ++i) {
            a[i] = _i(vectors, p + i * 4);
        }
        RenderState memory rs = _state(uint32(a[1]), uint32(a[2]));
        rs.centery = a[15];
        rs.fuzzpos = uint32(a[14]);
        DrawColumn memory dc = DrawColumn(
            a[3],
            a[4],
            a[5],
            a[6],
            a[7],
            _pattern(8192, 37, 19),
            uint32(a[8]),
            _pattern(256, 7, 3),
            new bytes(256)
        );
        bytes memory translations = R_Draw.R_InitTranslationTables();
        for (uint256 i; i < 256; ++i) {
            dc.translation[i] = translations[i + 256];
        }
        DrawSpan memory ds = DrawSpan(a[3], a[4], a[5], a[9], a[10], a[11], a[12], dc.source, dc.colormap);
        _apply(rs, dc, ds, uint32(a[0]));
        require(sha256(rs.framebuffer) == _digest(vectors, p + 64), "original C full-frame mismatch");
        require(
            dc.x == _i(vectors, p + 96) && dc.yl == _i(vectors, p + 100) && dc.yh == _i(vectors, p + 104),
            "column side effects"
        );
        require(ds.x1 == _i(vectors, p + 108) && ds.x2 == _i(vectors, p + 112), "span side effects");
        require(rs.fuzzpos == uint32(_i(vectors, p + 116)), "fuzzpos");
        require(
            rs.viewwindowx == _i(vectors, p + 120) && rs.viewwindowy == _i(vectors, p + 124), "view offsets"
        );
        require(_lookups(rs) == _digest(vectors, p + 128), "original lookup mismatch");
    }

    function _op(uint256 op) private pure {
        bytes memory data = DrawVectors.data();
        require(data.length == 95 * 160);
        for (uint256 p; p < data.length; p += 160) {
            if (uint32(_i(data, p)) == op) _case(data, p);
        }
    }

    function testOriginalColumnPixels() public pure {
        _op(0);
    }

    function testOriginalLowColumnPixelsAndMutation() public pure {
        _op(1);
    }

    function testOriginalTranslatedInteriorPointers() public pure {
        _op(2);
    }

    function testOriginalFuzzPixelsAndState() public pure {
        _op(3);
    }

    function testOriginalSpanPixels() public pure {
        _op(4);
    }

    function testOriginalLowSpanCountQuirkAndMutation() public pure {
        _op(5);
    }

    function testOriginalVideoErase() public pure {
        _op(6);
    }

    function testOriginalTranslationTables() public pure {
        _op(7);
    }

    function testOriginalBufferLookups() public pure {
        _op(8);
    }

    function invalid(uint256 which) external pure {
        RenderState memory rs = _state(320, 200);
        DrawColumn memory dc =
            DrawColumn(0, 0, 199, 65536, 0, new bytes(128), 0, new bytes(256), new bytes(256));
        DrawSpan memory ds = DrawSpan(0, 0, 319, 0, 0, 65536, 0, new bytes(4096), dc.colormap);
        if (which == 0) {
            dc.x = -1;
            R_Draw.R_DrawColumn(rs, dc);
        } else if (which == 1) {
            dc.yh = 200;
            R_Draw.R_DrawColumn(rs, dc);
        } else if (which == 2) {
            dc.sourceOffset = 1;
            dc.texturemid = 127 << 16;
            R_Draw.R_DrawColumn(rs, dc);
        } else if (which == 3) {
            dc.texturemid = -65536;
            R_Draw.R_DrawTranslatedColumn(rs, dc);
        } else if (which == 4) {
            dc.x = 160;
            R_Draw.R_DrawColumnLow(rs, dc);
        } else if (which == 5) {
            rs.fuzzpos = 50;
            R_Draw.R_DrawFuzzColumn(rs, dc, new bytes(7 * 256));
        } else if (which == 6) {
            ds.y = 200;
            R_Draw.R_DrawSpan(rs, ds);
        } else if (which == 7) {
            ds.x1 = 1;
            ds.x2 = 0;
            R_Draw.R_DrawSpan(rs, ds);
        } else if (which == 8) {
            ds.y = 199;
            ds.x2 = 159;
            R_Draw.R_DrawSpanLow(rs, ds);
        } else if (which == 9) {
            ds.source = new bytes(4095);
            R_Draw.R_DrawSpan(rs, ds);
        } else if (which == 10) {
            R_Draw.R_InitBuffer(rs, 319, 200);
        } else if (which == 11) {
            R_Draw.R_VideoErase(rs, new bytes(64000), 63999, 2);
        } else if (which == 12) {
            dc.colormap = new bytes(255);
            R_Draw.R_DrawColumn(rs, dc);
        } else if (which == 13) {
            dc.translation = new bytes(255);
            R_Draw.R_DrawTranslatedColumn(rs, dc);
        } else if (which == 14) {
            rs.ylookup[0] = 64000;
            R_Draw.R_DrawColumn(rs, dc);
        } else if (which == 15) {
            R_Draw.R_DrawFuzzColumn(rs, dc, new bytes(1791));
        } else {
            revert("unknown test");
        }
    }

    function testBoundsRejections() public {
        for (uint256 i; i < 16; ++i) {
            (bool ok, bytes memory err) = address(this).call(abi.encodeCall(this.invalid, (i)));
            require(!ok && bytes4(err) == R_Draw.DrawBounds.selector, "expected explicit DrawBounds");
        }
    }

    function probe(uint32 op)
        external
        view
        returns (uint256 usedGas, uint256 allocatedBefore, uint256 allocatedAfter, bytes32 digest)
    {
        RenderState memory rs = _state(320, 200);
        DrawColumn memory dc = DrawColumn(
            13, 0, 199, 65536, 0, _pattern(8192, 37, 19), 0, _pattern(256, 7, 3), _pattern(256, 1, 0)
        );
        DrawSpan memory ds = DrawSpan(100, 0, 319, 0, 0, 65536, 0, dc.source, dc.colormap);
        if (op == 5) ds.x2 = 79;
        bytes memory maps;
        if (op == 3) {
            maps = new bytes(7 * 256);
            for (uint256 m; m < 7; ++m) {
                for (uint256 i; i < 256; ++i) {
                    maps[m * 256 + i] = bytes1(uint8(m * 11 + i * 7 + 3));
                }
            }
        }
        assembly ("memory-safe") { allocatedBefore := mload(0x40) }
        uint256 start = gasleft();
        if (op == 3) R_Draw.R_DrawFuzzColumn(rs, dc, maps);
        else _apply(rs, dc, ds, op);
        usedGas = start - gasleft();
        assembly ("memory-safe") { allocatedAfter := mload(0x40) }
        digest = sha256(rs.framebuffer);
    }

    function testMeasuredPrimitives() public {
        for (uint32 op; op < 6; ++op) {
            (uint256 g, uint256 beforeMem, uint256 afterMem, bytes32 digest) = this.probe(op);
            require(digest != bytes32(0));
            emit log_named_uint("operation", op);
            emit log_named_uint("draw gas (excluding fixture setup and SHA)", g);
            emit log_named_uint("allocator before", beforeMem);
            emit log_named_uint("allocator after", afterMem);
        }
    }
}
