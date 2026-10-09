// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {R_Data} from "../doom/r_data.sol";
import {ResourceView, RenderResources, ColumnView} from "../doom/r_data_types.sol";
import {ResourceIdentity, LumpDescriptor} from "../evm/ResourceTypes.sol";
import {MapData} from "../doom/r_defs.sol";

/// @notice Phase 2 ordinary-EVM measurement fixture, not the production renderer.
/// @dev Separate instrumented deployment replaces ONLY the source-mapped GAS opcode in
/// memorySize with MSIZE. Both instructions cost two gas and push one word. The benchmark
/// verifies all other runtime bytes, operation gas deltas and output digests are unchanged.
contract ResourceAccessProbe {
    ResourceView private resources;
    struct Report { uint256[5] cost; uint256[6] footprint; bytes32 digest; }

    constructor(address[] memory chunks, bytes memory directory) {
        require(chunks.length == 1755 && directory.length == 3163 * 16, "pinned resource dimensions");
        resources.identity = ResourceIdentity(
            0,
            0x7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d,
            0xd379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47,
            0xfd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb,
            0
        );
        resources.byteLength = 28741889;
        for (uint256 i; i < chunks.length; i++) {
            require(chunks[i].code.length == (i == 1754 ? 4354 : 16385), "invalid deployed chunk length");
            resources.chunks.push(chunks[i]);
        }
        for (uint256 i; i < 3163; i++) {
            uint256 p = i * 16;
            bytes8 name;
            assembly ("memory-safe") { name := mload(add(add(directory, 32), p)) }
            resources.lumps.push(LumpDescriptor(name, le32(directory, p + 8), le32(directory, p + 12)));
        }
    }

    function le32(bytes memory data, uint256 p) private pure returns (uint32) {
        return uint32(uint8(data[p])) | uint32(uint8(data[p + 1])) << 8 | uint32(uint8(data[p + 2])) << 16
            | uint32(uint8(data[p + 3])) << 24;
    }

    function memorySize() private view returns (uint256 size) {
        // MSIZE_PATCH_MARKER: this exact GAS is the only instrumentation target.
        assembly ("memory-safe") { size := gas() }
    }

    /// @dev memory[0]: entry, [1]: decoded ResourceView, [2..4]: operation boundaries,
    /// [5]: after output checksum. GAS placeholders in normal deployment are not memory claims.
    function loadSource(Report memory report) private view returns(ResourceView memory v) {
        report.footprint[0]=memorySize();uint256 start=gasleft();v=resources;
        report.cost[0]=start-gasleft();report.footprint[1]=memorySize();
    }
    function setup(Report memory report,bool eager) private view returns(RenderResources memory r) {
        ResourceView memory v=loadSource(report);uint256 start=gasleft();
        r=eager?R_Data.R_InitData(v):R_Data.R_InitDataLazy(v);
        report.cost[1]=start-gasleft();report.footprint[2]=memorySize();
    }
    function probeRead() external view returns(Report memory report) {
        ResourceView memory v=loadSource(report);uint256 start=gasleft();
        bytes memory value=R_Data.read(v,16380,16);report.cost[1]=start-gasleft();report.footprint[2]=memorySize();
        report.digest=sha256(value);report.footprint[5]=memorySize();
    }
    function probeInit(bool eager) external view returns(Report memory report) {
        RenderResources memory r=setup(report,eager);
        report.digest=sha256(abi.encode(uint256(r.textures.length),uint256(r.firstflat),uint256(r.numflats),uint256(r.firstspritelump),uint256(r.numspritelumps),sha256(r.colormaps)));
        report.footprint[5]=memorySize();
    }
    function probeMap() external view returns(Report memory report) {
        RenderResources memory r=setup(report,false);uint256 start=gasleft();
        MapData memory m=R_Data.R_LoadMap(r,"E1M1");report.cost[2]=start-gasleft();report.footprint[3]=memorySize();
        report.digest=sha256(abi.encode(uint256(m.vertexes.length),uint256(m.sectors.length),uint256(m.sides.length),uint256(m.lines.length),uint256(m.segs.length),uint256(m.subsectors.length),uint256(m.nodes.length),uint256(m.things.length)));
        report.footprint[5]=memorySize();
    }
    function probeColumns() external view returns(Report memory report) {
        RenderResources memory r=setup(report,false);uint256 start=gasleft();
        ColumnView memory a=R_Data.R_GetColumn(r,2,0);report.cost[2]=start-gasleft();report.footprint[3]=memorySize();
        start=gasleft();ColumnView memory b=R_Data.R_GetColumn(r,2,1);report.cost[3]=start-gasleft();report.footprint[4]=memorySize();
        report.digest=sha256(abi.encode(sha256(a.data),uint256(a.offset),sha256(b.data),uint256(b.offset)));
        report.footprint[5]=memorySize();
    }
    function probeFlats() external view returns(Report memory report) {
        RenderResources memory r=setup(report,false);uint256 start=gasleft();
        bytes memory a=R_Data.R_GetFlat(r,1);report.cost[2]=start-gasleft();report.footprint[3]=memorySize();
        start=gasleft();bytes memory b=R_Data.R_GetFlat(r,1);report.cost[3]=start-gasleft();report.footprint[4]=memorySize();
        report.digest=sha256(abi.encode(sha256(a),sha256(b)));report.footprint[5]=memorySize();
    }
}
