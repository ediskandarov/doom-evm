// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {Z_ZoneBacking} from "../../src/doom/z_zone_backing.sol";
import {ZoneState, ZoneConst as C} from "../../src/doom/z_zone_types.sol";
import {RenderResources} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

contract PointerHighBytesTest {
    function testExplicitAddressDomainEstablishesOnlyCurrentPointerHighBytes() public view {
        RenderResources memory r;
        r.nativeZone = Z_Zone.Z_Init(8192, 2);
        r.source.lumps = new LumpDescriptor[](2);
        uint32 source = Z_Zone.Z_Malloc(r.nativeZone, 512, C.PU_CACHE, 0);
        Z_Zone.Z_Malloc(r.nativeZone, 4096, C.PU_CACHE, 1);
        (bytes memory beforeData, bytes memory beforeKnown) =
            Z_ZoneBacking.tailWithProvenance(r, source, 512, 40);
        beforeData;
        require(beforeKnown[15] == 0, "legacy pointer remains unknown");
        r.nativeZone.canonicalPointerHighBytes = true;
        (bytes memory data, bytes memory known) = Z_ZoneBacking.tailWithProvenance(r, source, 512, 40);
        for (uint256 i; i < 40; ++i) {
            bool high = i == 14 || i == 15 || i == 30 || i == 31 || i == 38 || i == 39;
            if (high) require(known[i] == 0x03 && data[i] == 0, "bounded original pointer high bytes");
            else require(known[i] == beforeKnown[i], "no other byte knownness changed");
        }
        (data, known) = Z_ZoneBacking.tail(r, source, 512, 16);
        require(data[15] == 0 && known[15] == 0x01, "draw marker represents explicit provenance");
        r.nativeZone.canonicalPointerHighBytes = false;
        (, known) = Z_ZoneBacking.tail(r, source, 512, 16);
        require(known[15] == 0, "strict guard retained");
    }
}
