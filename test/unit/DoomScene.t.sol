// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {DoomScene, StaticCamera} from "../../src/evm/DoomScene.sol";
import {MapData, MapThing, Subsector, Sector} from "../../src/doom/r_defs.sol";

contract DoomSceneTest {
    function mapWithRoom() private pure returns (MapData memory map) {
        map.subsectors = new Subsector[](1);
        map.sectors = new Sector[](1);
        map.sectors[0].ceilingheight = 128 * 65536;
        map.things = new MapThing[](3);
    }

    function testPlayerStartSelectionAngleAndStationaryHeight() public pure {
        MapData memory map = mapWithRoom();
        map.things[0] = MapThing(10, 20, 45, 1, 0);
        map.things[1] = MapThing(30, 40, 90, 2, 0); // another player is not camera one.
        map.things[2] = MapThing(-12, 34, -46, 1, 0);
        StaticCamera memory camera = DoomScene.playerStart(map);
        require(camera.x == -12 * 65536 && camera.y == 34 * 65536, "last player-one start");
        require(camera.angle == 0xe0000000, "signed angle division then binary-angle wrap");
        require(camera.z == 41 * 65536, "stationary eye height");
        map.sectors[0].ceilingheight = 40 * 65536;
        camera = DoomScene.playerStart(map);
        require(camera.z == 36 * 65536, "ceiling clearance clamp");
    }

    function absentStart() external pure {
        DoomScene.playerStart(mapWithRoom());
    }

    function testMissingPlayerStartRejected() public view {
        try this.absentStart() {
            revert("missing start accepted");
        } catch (bytes memory reason) {
            require(bytes4(reason) == DoomScene.MissingPlayerStart.selector);
        }
    }
}
