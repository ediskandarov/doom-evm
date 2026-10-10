// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {EpisodeStartup} from "../../src/evm/EpisodeStartup.sol";
import {GameContext, GameConst, PlayerState} from "../../src/doom/p_game_state.sol";
import {GameflowState} from "../../src/doom/g_game.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {ResourceIdentity, LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {R_Data} from "../../src/doom/r_data.sol";
import {EpisodeStartupSnapshot as Snapshot} from "../../src/support/EpisodeStartupSnapshot.sol";
import {Z_Zone} from "../../src/doom/z_zone.sol";
import {ZoneConst} from "../../src/doom/z_zone_types.sol";
import {P_Zone_Setup} from "../../src/doom/p_zone_setup.sol";

interface EpisodeVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
}

contract EpisodeStartupTest {
    EpisodeVm constant vm = EpisodeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    event StartupGas(int32 map, int32 skill, bool nomonsters, uint256 gasUsed);

    function setUp() public {
        for (uint256 i; i < 1755; ++i) {
            this.install(i);
        }
    }

    function install(uint256 i) external {
        vm.etch(
            address(uint160(0x100000 + i)),
            vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"))
        );
    }

    function source() private view returns (ResourceView memory v) {
        v.identity = ResourceIdentity(
            0,
            0x7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d,
            0xd379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47,
            0xfd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb,
            0
        );
        v.byteLength = 28741889;
        v.chunks = new address[](1755);
        for (uint256 i; i < v.chunks.length; ++i) {
            v.chunks[i] = address(uint160(0x100000 + i));
        }
        bytes memory directory = vm.readFileBinary("test/fixtures/phase2_data/directory.bin");
        v.lumps = new LumpDescriptor[](3163);
        for (uint256 i; i < v.lumps.length; ++i) {
            uint256 p = i * 16;
            bytes8 name;
            // Each record owns16 bytes and name occupies its first8 bytes.
            assembly ("memory-safe") { name := mload(add(add(directory, 32), p)) }
            v.lumps[i] = LumpDescriptor(name, le32(directory, p + 8), le32(directory, p + 12));
        }
    }

    function le32(bytes memory data, uint256 p) private pure returns (uint32) {
        return uint32(uint8(data[p])) | uint32(uint8(data[p + 1])) << 8 | uint32(uint8(data[p + 2])) << 16
            | uint32(uint8(data[p + 3])) << 24;
    }

    function expected(string memory name, string memory file) private view returns (bytes32) {
        return sha256(
            vm.readFileBinary(string.concat("test/fixtures/phase4_episode_startup/", name, "/", file, ".bin"))
        );
    }

    function compare(int32 map, int32 skill, bool nomonsters, bool deterministic)
        private
        view
        returns (GameContext memory c)
    {
        ResourceView memory v = source();
        uint256 start = gasleft();
        GameflowState memory f;
        (c, f) = EpisodeStartup.initialize(v, 1, map, skill, nomonsters, deterministic);
        // Report-only gas is emitted by non-view test wrappers below.
        start;
        string memory name = string.concat(
            "E1M",
            vm.toString(uint32(map)),
            "-skill",
            vm.toString(uint32(skill)),
            nomonsters ? "-nomonsters" : ""
        );
        require(
            sha256(Snapshot.observe(c.state)) == expected(name, "world"), "native full DSG1 startup world"
        );
        require(
            sha256(Snapshot.collision(c.state)) == expected(name, "collision"),
            "native blockmap/reject/grouping/starts/scrollers"
        );
        require(
            sha256(Snapshot.zone(c.state.nativeZone)) == expected(name, "zone"),
            "native complete live zone headers and owners"
        );
        require(sha256(Snapshot.flow(c.state, f)) == expected(name, "flow"), "native startup flow globals");
        require(sha256(Snapshot.difficulty(c)) == expected(name, "difficulty"), "native mutable difficulty");
        require(f.initialized && f.wminfo.partime == 180 && f.wminfo.maxfrags == 0, "complete setup defaults");
        require(
            c.state.gametic == 0 && c.state.leveltime == 0 && c.state.gameepisode == 1
                && c.state.gamemap == map,
            "no startup tic"
        );
        require(
            c.state.players[0].playerstate == PlayerState.live
                && c.state.mobjs[c.state.players[0].mo].allocated,
            "live player"
        );
        require(c.state.nativeZone.deterministicInitialization == deterministic, "backing policy preserved");
        // Actual memory aliases, not merely equal serialized data.
        int32 old = c.map.sectors[0].floorheight;
        c.map.sectors[0].floorheight = old + 1;
        require(c.state.map.sectors[0].floorheight == old + 1, "map aliases state");
        c.map.sectors[0].floorheight = old;
        require(c.resources.nativeZone.rover == c.state.nativeZone.rover, "zone alias");
    }

    function case_(int32 map, int32 skill, bool nomonsters, bool deterministic) private {
        uint256 start = gasleft();
        compare(map, skill, nomonsters, deterministic);
        emit StartupGas(map, skill, nomonsters, start - gasleft());
    }

    function testNativeE1M1Compatibility() public {
        case_(1, 2, false, true);
    }

    function testNativeE1M2Startup() public {
        case_(2, 2, false, true);
    }

    function testNativeE1M3Startup() public {
        case_(3, 2, false, true);
    }

    function testNativeE1M4Startup() public {
        case_(4, 2, false, true);
    }

    function testNativeE1M5Startup() public {
        case_(5, 2, false, true);
    }

    function testNativeE1M6Startup() public {
        case_(6, 2, false, true);
    }

    function testNativeE1M7Startup() public {
        case_(7, 2, false, true);
    }

    function testNativeE1M8Startup() public {
        case_(8, 2, false, true);
    }

    function testNativeE1M9Startup() public {
        case_(9, 2, false, true);
    }

    function testNativeE1M2Baby() public {
        case_(2, 0, false, true);
    }

    function testNativeE1M2Nightmare() public {
        case_(2, 4, false, true);
    }

    function testNativeE1M2NoMonsters() public {
        case_(2, 2, true, true);
    }

    function testStrictPolicyChangesNoLogicalSetupOrAllocation() public {
        case_(2, 2, false, false);
    }

    function testLevelTagsFreeOnlyLevelOwnedAllocations() public view {
        GameContext memory c = compare(2, 2, false, true);
        uint32 owner = R_Data.W_GetNumForName(c.resources.source, "COLORMAP");
        uint32 retained = c.state.nativeZone.ownerBlocks[owner];
        // A new semantic cache call tests retained static ownership; no map reload or transition.
        uint32 staticBlock = Z_Zone.Z_Malloc(c.state.nativeZone, 128, ZoneConst.PU_STATIC, ZoneConst.NULL);
        uint32 cacheBlock = Z_Zone.Z_Malloc(c.state.nativeZone, 128, ZoneConst.PU_CACHE, owner);
        P_Zone_Setup.begin(c);
        Z_Zone.Z_CheckHeap(c.state.nativeZone);
        require(
            c.state.nativeZone.blocks[staticBlock].allocated
                && c.state.nativeZone.blocks[cacheBlock].allocated,
            "static/cache survive level free"
        );
        for (uint32 id = c.state.nativeZone.blocks[0].next; id != 0; id = c.state.nativeZone.blocks[id].next) {
            require(
                !c.state.nativeZone.blocks[id].allocated || c.state.nativeZone.blocks[id].tag < 50
                    || c.state.nativeZone.blocks[id].tag >= 100,
                "level tags freed"
            );
        }
        require(c.state.nativeZone.deterministicInitialization, "level free preserves initial-memory policy");
        retained;
    }

    function validate(ResourceView memory v) external view {
        EpisodeStartup.validate(v);
    }

    function select(int32 episode, int32 map, int32 skill) external view {
        EpisodeStartup.initialize(source(), episode, map, skill, false, true);
    }

    function reject(bytes memory data, bytes4 selector) private view {
        (bool ok, bytes memory error_) = address(this).staticcall(data);
        require(!ok && bytes4(error_) == selector, "exact resource/selection error");
    }

    function testSelectionDomainRejectsOutsideEpisodeOne() public view {
        reject(abi.encodeCall(this.select, (2, 1, 2)), EpisodeStartup.UnsupportedSelection.selector);
        reject(abi.encodeCall(this.select, (1, 0, 2)), EpisodeStartup.UnsupportedSelection.selector);
        reject(abi.encodeCall(this.select, (1, 10, 2)), EpisodeStartup.UnsupportedSelection.selector);
        reject(abi.encodeCall(this.select, (1, 2, -1)), EpisodeStartup.UnsupportedSelection.selector);
        reject(abi.encodeCall(this.select, (1, 2, 5)), EpisodeStartup.UnsupportedSelection.selector);
    }

    function testIdentityDirectoryAndRuntimeOrderAreAuthenticated() public view {
        ResourceView memory v = source();
        v.identity.paletteVariant = 1;
        reject(abi.encodeCall(this.validate, (v)), EpisodeStartup.ResourceIdentityMismatch.selector);
        v = source();
        v.lumps[15].offset++;
        reject(abi.encodeCall(this.validate, (v)), EpisodeStartup.ResourceDirectoryMismatch.selector);
        v = source();
        (v.chunks[0], v.chunks[1]) = (v.chunks[1], v.chunks[0]);
        reject(abi.encodeCall(this.validate, (v)), EpisodeStartup.ResourceChunksMismatch.selector);
        v = source();
        v.chunks[1754] = address(0);
        reject(abi.encodeCall(this.validate, (v)), EpisodeStartup.ResourceChunksMismatch.selector);
    }
}
