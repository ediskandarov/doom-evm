// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {StackPressure} from "../../src/support/StackPressure.sol";

contract StackPressureTest {
    StackPressure private spike = new StackPressure();

    function scene() internal pure returns (StackPressure.Scene memory s) {
        s.frontCeiling = 128;
        s.viewz = 64;
        s.backCeiling = 96;
        s.backFloor = 32;
        s.midtexture = 1;
        s.toptexture = 2;
        s.bottomtexture = 3;
        s.lightlevel = 128;
    }

    function testSingleSidedEdgeRecurrence() public view {
        StackPressure.Trace memory t = spike.R_StoreWallRange(scene(), 0, 3);
        require(t.columns == 4 && t.tiers == 1 && t.silhouette == 3, "single sided");
        require(t.markfloor && t.markceiling && t.planeChecks == 2, "planes");
        require(t.scalestep == 1 && t.topstep == -4 && t.bottomstep == 4, "steps");
        require(t.finalscale == 20 && t.finaltop == 20 && t.finalbottom == 180, "edges");
        require(t.texturemid == 64 && t.checksum == 300, "texture dependency");
    }

    function testSingleColumnAndBottomPeg() public view {
        StackPressure.Scene memory s = scene();
        s.dontPegBottom = true;
        s.rowoffset = 7;
        StackPressure.Trace memory t = spike.R_StoreWallRange(s, 5, 5);
        require(t.columns == 1 && t.scalestep == 0 && t.finalscale == 21, "single column");
        require(t.texturemid == 8 && t.topstep == 0 && t.bottomstep == 0, "peg/edges");
    }

    function testTwoSidedTiersMaskedClipAllocation() public view {
        StackPressure.Scene memory s = scene();
        s.backsector = true;
        StackPressure.Trace memory t = spike.R_StoreWallRange(s, 0, 3);
        require(t.tiers == 14 && t.columns == 4 && t.openings == 12, "tiers/masked allocation");
        require(t.silhouette == 3 && t.planeChecks == 2, "masked silhouette");
        require(t.toptexturemid == 98 && t.bottomtexturemid == -32, "unpegged");
        require(t.pixhighstep == -2 && t.pixlowstep == 2, "tier steps");
        require(t.finalhigh == 60 && t.finallow == 140, "tier recurrence");
        require(t.checksum == 1114, "all tier dependencies");
        s.dontPegTop = true;
        s.dontPegBottom = true;
        t = spike.R_StoreWallRange(s, 0, 3);
        require(t.toptexturemid == 64 && t.bottomtexturemid == 64, "pegged");
    }

    function testUntexturedIdenticalPlanesAndSky() public view {
        StackPressure.Scene memory s = scene();
        s.backsector = true;
        s.backCeiling = s.frontCeiling;
        s.backFloor = s.frontFloor;
        s.midtexture = 0;
        StackPressure.Trace memory t = spike.R_StoreWallRange(s, 0, 3);
        require(t.tiers == 0 && t.checksum == 0 && t.planeChecks == 0, "identical planes");
        require(t.openings == 0 && t.silhouette == 0, "no clipping");
        s.backCeiling = 96;
        s.sky = true;
        t = spike.R_StoreWallRange(s, 0, 3);
        require(t.tiers == 0 && !t.markceiling && t.finaltop == 60, "sky joins ceilings");
    }

    function testClosedDoorAndViewPlaneSuppression() public view {
        StackPressure.Scene memory s = scene();
        s.backsector = true;
        s.backCeiling = s.frontFloor;
        StackPressure.Trace memory t = spike.R_StoreWallRange(s, 0, 1);
        require(t.markfloor && t.markceiling && t.silhouette == 3, "closed door");
        s.backsector = false;
        s.frontFloor = s.viewz;
        s.frontCeiling = s.viewz;
        t = spike.R_StoreWallRange(s, 0, 1);
        require(!t.markfloor && !t.markceiling && t.planeChecks == 0, "wrong view side");
        s.sky = true;
        t = spike.R_StoreWallRange(s, 0, 1);
        require(t.markceiling, "sky visible");
    }

    function testLightingClampAndAngleClamp() public view {
        StackPressure.Scene memory s = scene();
        s.angle = -180;
        s.extralight = -20;
        StackPressure.Trace memory t = spike.R_StoreWallRange(s, 0, 1);
        require(t.light == 0 && t.distance == 16 && t.offset == -64, "lower clamp/angle");
        s.extralight = 20;
        t = spike.R_StoreWallRange(s, 0, 1);
        require(t.light == 15, "upper clamp");
        s.extralight = 0;
        s.orientation = -1;
        t = spike.R_StoreWallRange(s, 0, 1);
        require(t.light == 7, "horizontal");
        s.orientation = 1;
        t = spike.R_StoreWallRange(s, 0, 1);
        require(t.light == 9, "vertical");
        s.fixedColormap = true;
        t = spike.R_StoreWallRange(s, 0, 1);
        require(t.light == 0, "fixed map bypass");
    }

    function testDrawsegLimitAndInvalidRange() public view {
        StackPressure.Scene memory s = scene();
        s.drawsegCount = 256;
        StackPressure.Trace memory t = spike.R_StoreWallRange(s, 0, 319);
        require(!t.mapped && t.columns == 0, "drawseg capacity");
        s.drawsegCount = 0;
        try spike.R_StoreWallRange(s, 3, 2) {
            revert("accepted inverted range");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) == keccak256("range"), "reason");
        }
        try spike.R_StoreWallRange(s, 0, 320) {
            revert("accepted width overflow");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) == keccak256("range"), "reason");
        }
    }

    function testFullWidthMaskedRuntime() public view {
        StackPressure.Scene memory s = scene();
        s.backsector = true;
        StackPressure.Trace memory t = spike.R_StoreWallRange(s, 0, 319);
        require(t.columns == 320 && t.openings == 960 && t.tiers == 14, "full width");
        require(t.finalscale == 336 && t.finalhigh == -572 && t.finallow == 772, "full edges");
    }

    function testFuzzColumnRangeAndEdgeRecurrence(uint16 rawStart, uint16 rawLength) public view {
        uint256 start = uint256(rawStart) % 320;
        uint256 count = 1 + uint256(rawLength) % (320 - start);
        StackPressure.Trace memory t = spike.R_StoreWallRange(scene(), start, start + count - 1);
        int256 step = count == 1 ? int256(0) : int256(1);
        int256 finalscale = 16 + int256(start) + step * int256(count);
        require(t.columns == count && t.finalscale == finalscale, "column recurrence");
        require(t.finaltop == 100 - 4 * finalscale && t.finalbottom == 100 + 4 * finalscale, "edges");
    }
}
