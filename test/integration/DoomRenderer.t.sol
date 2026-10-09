// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {DoomRenderer} from "../../src/evm/DoomRenderer.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {ResourceIdentity, LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {RenderContext} from "../../src/doom/r_render_state.sol";

interface RendererVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function readFile(string calldata) external view returns (string memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
    function parseJsonString(string calldata, string calldata) external pure returns (string memory);
    function parseJsonUint(string calldata, string calldata) external pure returns (uint256);
    function parseJsonInt(string calldata, string calldata) external pure returns (int256);
    function parseBytes32(string calldata) external pure returns (bytes32);
}

contract DoomRendererTest {
    RendererVm constant vm = RendererVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    error PixelMismatch(uint256 index, bytes1 expected, bytes1 actual);
    event FullFrameGas(uint256 angle, uint256 initialization, uint256 rendering);

    function installChunk(uint256 i) external {
        vm.etch(
            address(uint160(0x100000 + i)),
            vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"))
        );
    }

    function setUp() public {
        for (uint256 i; i < 1755; ++i) {
            this.installChunk(i);
        }
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
        for (uint256 i; i < 1755; ++i) {
            v.chunks[i] = address(uint160(0x100000 + i));
        }
        bytes memory d = vm.readFileBinary("test/fixtures/phase2_data/directory.bin");
        v.lumps = new LumpDescriptor[](d.length / 16);
        for (uint256 i; i < v.lumps.length; ++i) {
            uint256 p = i * 16;
            bytes8 name;
            assembly ("memory-safe") { name := mload(add(add(d, 32), p)) }
            v.lumps[i] = LumpDescriptor(name, le32(d, p + 8), le32(d, p + 12));
        }
    }

    function le32(bytes memory d, uint256 p) private pure returns (uint32 value) {
        for (uint256 i; i < 4; ++i) {
            value |= uint32(uint8(d[p + i])) << uint32(8 * i);
        }
    }

    function hashField(string memory doc, string memory key) private pure returns (bytes32) {
        return vm.parseBytes32(string.concat("0x", vm.parseJsonString(doc, key)));
    }

    function check(uint32 angleIndex) private {
        string memory name = string.concat("full-angle", vm.toString(angleIndex));
        string memory manifest = vm.readFile("test/fixtures/renderer/manifest.json");
        string memory key;
        for (uint256 i; i < 16; ++i) {
            string memory candidate = string.concat(".cases[", vm.toString(i), "]");
            if (
                keccak256(bytes(vm.parseJsonString(manifest, string.concat(candidate, ".name"))))
                    == keccak256(bytes(name))
            ) {
                key = candidate;
                break;
            }
        }
        require(bytes(key).length != 0, "missing full native case");
        require(
            keccak256(bytes(vm.parseJsonString(manifest, string.concat(key, ".mode")))) == keccak256("full"),
            "full pass required"
        );
        uint32 angle = angleIndex * 0x20000000;
        require(vm.parseJsonUint(manifest, string.concat(key, ".angle")) == angle, "native angle");
        string memory directory = string.concat("test/fixtures/renderer/", name, "/");
        string memory refdoc = vm.readFile(string.concat(directory, "reference.json"));
        bytes memory expected = vm.readFileBinary(string.concat(directory, "pixels.bin"));
        require(
            expected.length == 64000
                && sha256(expected) == hashField(manifest, string.concat(key, ".frameSha256")),
            "manifest pixel identity"
        );
        require(sha256(expected) == hashField(refdoc, ".frameSha256"), "reference pixel identity");
        require(
            vm.parseJsonUint(refdoc, ".schemaVersion") == 0 && vm.parseJsonUint(refdoc, ".width") == 320
                && vm.parseJsonUint(refdoc, ".height") == 200,
            "reference frame format"
        );
        require(
            vm.parseJsonInt(refdoc, ".lighting.fixedColormap") == -1
                && vm.parseJsonInt(refdoc, ".lighting.extraLight") == 0
                && vm.parseJsonUint(refdoc, ".gametic") == 0,
            "static lighting/tic"
        );
        ResourceView memory v = source();
        require(
            hashField(refdoc, ".resourceIdentity.wadSha256") == v.identity.wadSha256
                && hashField(refdoc, ".resourceIdentity.bundleSha256") == v.identity.bundleSha256
                && hashField(refdoc, ".resourceIdentity.paletteSha256") == v.identity.paletteSha256,
            "reference resources"
        );
        require(
            keccak256(bytes(vm.parseJsonString(refdoc, ".provenance.map"))) == keccak256("E1M1")
                && keccak256(bytes(vm.parseJsonString(refdoc, ".detail"))) == keccak256("high"),
            "map/detail"
        );
        uint256 start = gasleft();
        RenderContext memory c = DoomRenderer.initialize(v);
        uint256 initialization = start - gasleft();
        require(
            c.rs.viewx == vm.parseJsonInt(refdoc, ".camera.x")
                && c.rs.viewy == vm.parseJsonInt(refdoc, ".camera.y")
                && c.rs.viewz == vm.parseJsonInt(refdoc, ".camera.z"),
            "EVM-derived camera"
        );
        c.rs.viewangle = angle;
        require(c.rs.viewangle == vm.parseJsonUint(refdoc, ".camera.angle"), "reference camera angle");
        start = gasleft();
        DoomRenderer.render(c);
        emit FullFrameGas(angle, initialization, start - gasleft());
        require(
            c.drawsegCount == vm.parseJsonUint(manifest, string.concat(key, ".scene.drawsegs")),
            "native drawseg count"
        );
        require(
            c.visplaneCount == vm.parseJsonUint(manifest, string.concat(key, ".scene.visplanes")),
            "native plane count"
        );
        require(
            c.sprite.visspriteCount == vm.parseJsonUint(manifest, string.concat(key, ".scene.vissprites")),
            "native sprite count"
        );
        require(
            c.rs.sscount == vm.parseJsonUint(manifest, string.concat(key, ".scene.subsectors")),
            "native subsector count"
        );
        require(c.rs.framebuffer.length == expected.length, "complete frame");
        for (uint256 i; i < expected.length; ++i) {
            if (c.rs.framebuffer[i] != expected[i]) {
                revert PixelMismatch(i, expected[i], c.rs.framebuffer[i]);
            }
        }
    }

    function testFullNativeAngle0() public {
        check(0);
    }

    function testFullNativeAngle1() public {
        check(1);
    }

    function testFullNativeAngle2() public {
        check(2);
    }

    function testFullNativeAngle3() public {
        check(3);
    }

    function testFullNativeAngle4() public {
        check(4);
    }

    function testFullNativeAngle5() public {
        check(5);
    }

    function testFullNativeAngle6() public {
        check(6);
    }

    function testFullNativeAngle7() public {
        check(7);
    }
}
