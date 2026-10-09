// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {Tables} from "../../src/doom/tables.sol";

contract TablesTest {
    function lookup(uint8 table, uint256 index) external pure returns (uint32) {
        if (table == 0) return uint32(Tables.finesine(index));
        if (table == 1) return uint32(Tables.finecosine(index));
        if (table == 2) return uint32(Tables.finetangent(index));
        return Tables.tantoangle(index);
    }

    function allWords(uint8 table, uint256 length) private view returns (bytes32) {
        bytes memory data = new bytes(length * 4);
        for (uint256 i; i < length; ++i) {
            // Separate call gives each lookup bounded scratch memory, as an eventual adapter can.
            uint32 word = this.lookup(table, i);
            data[i * 4] = bytes1(uint8(word));
            data[i * 4 + 1] = bytes1(uint8(word >> 8));
            data[i * 4 + 2] = bytes1(uint8(word >> 16));
            data[i * 4 + 3] = bytes1(uint8(word >> 24));
        }
        return sha256(data);
    }

    // Expected complete-table digests are generated from pinned original C and compiled natively.
    function testEverySineLookupMatchesOriginalC() public view {
        require(allWords(0, 10240) == 0xa2a1181edd988c7f3f8220c8ffa82801d7c3bbf7ca9564551e90d877728a2ebb);
    }

    function testEveryCosineAliasMatchesOriginalC() public view {
        require(allWords(1, 8192) == 0xec1f6386e7fb9165608705ff3561f538b7f41c5103d1b6c723dfef07a8f85cbf);
    }

    function testEveryTangentLookupMatchesOriginalC() public view {
        require(allWords(2, 4096) == 0x8988638b066ed2b19a42c6ea1f7d451744e8337845bba4cbb08ac400e521a031);
    }

    function testEveryTantoangleLookupMatchesOriginalC() public view {
        require(allWords(3, 2049) == 0xba4346ce3ac3dcb24c460bcf0ed98d3f8351203ca3bcc1dec1cb822f9dee7e11);
    }

    function testAllBoundsRejectInsteadOfWrapping() public view {
        uint256[4] memory lengths = [uint256(10240), 8192, 4096, 2049];
        for (uint8 table; table < 4; ++table) {
            for (uint256 trial; trial < 2; ++trial) {
                uint256 index = trial == 0 ? lengths[table] : type(uint256).max;
                try this.lookup(table, index) returns (uint32) {
                    revert("out-of-range lookup accepted");
                } catch (bytes memory reason) {
                    require(
                        keccak256(reason)
                            == keccak256(
                                abi.encodeWithSelector(
                                    Tables.TableIndexOutOfBounds.selector, index, lengths[table]
                                )
                            ),
                        "wrong bounds error"
                    );
                }
            }
        }
    }

    function testConstantsAndCardinalAngles() public pure {
        require(Tables.FINEANGLES == 8192 && Tables.FINEMASK == 8191 && Tables.ANGLETOFINESHIFT == 19);
        require(Tables.ANG45 == 0x20000000 && Tables.ANG90 == 0x40000000);
        require(Tables.ANG180 == 0x80000000 && Tables.ANG270 == 0xc0000000);
        require(Tables.SLOPERANGE == 2048 && Tables.SLOPEBITS == 11 && Tables.DBITS == 5);
        require(Tables.tantoangle(0) == 0 && Tables.tantoangle(2048) == Tables.ANG45);
        // Tables use half-step samples: sin(0) is intentionally 25, not regenerated as zero.
        require(Tables.finesine(0) == 25 && Tables.finecosine(0) == 65535);
    }

    function testSlopeDivUnsignedWrapAndCutoffs() public pure {
        require(Tables.SlopeDiv(0, 511) == 2048);
        require(Tables.SlopeDiv(0, 512) == 0);
        require(Tables.SlopeDiv(512, 512) == 2048);
        require(Tables.SlopeDiv(0x20000000, 512) == 0, "num shift must wrap uint32");
        require(Tables.SlopeDiv(0x20000001, 512) == 4);
    }
}
