// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {WiState, WiStart, WiInput, WiGraphics} from "../doom/wi_stuff_types.sol";
import {WI_Stuff as WI} from "../doom/wi_stuff.sol";
import {VideoState} from "../doom/v_video_types.sol";
import {V_Video as V} from "../doom/v_video.sol";
import {M_BBox} from "../doom/m_bbox.sol";
import {ResourceView} from "../doom/r_data_types.sol";

/// @dev Verification only: big-endian scripted commands, observation serialization.
/// No expected state, pixels or gameplay is supplied to WI.
library IntermissionFixture {
    error InvalidFixture();

    function word(bytes memory b, uint256 cursor) internal pure returns (int32) {
        if (cursor + 4 > b.length) revert InvalidFixture();
        return int32(
            (uint32(uint8(b[cursor])) << 24) | (uint32(uint8(b[cursor + 1])) << 16)
                | (uint32(uint8(b[cursor + 2])) << 8) | uint32(uint8(b[cursor + 3]))
        );
    }

    function start(
        bytes memory data,
        WiState memory s,
        WiInput memory p,
        WiGraphics memory a,
        VideoState memory v,
        ResourceView memory source
    ) internal view {
        if (data.length < 64) revert InvalidFixture();
        WiStart memory w;
        p.gamemode = word(data, 0);
        w.last = word(data, 4);
        w.next = word(data, 8);
        w.didsecret = word(data, 12) != 0;
        w.maxkills = word(data, 16);
        w.maxitems = word(data, 20);
        w.maxsecret = word(data, 24);
        w.plyr[0].skills = word(data, 28);
        w.plyr[0].sitems = word(data, 32);
        w.plyr[0].ssecret = word(data, 36);
        w.plyr[0].stime = word(data, 40);
        w.partime = word(data, 44);
        p.playeringame[0] = true;
        p.attackdown[0] = word(data, 48);
        p.usedown[0] = word(data, 52);
        p.rndindex = uint32(word(data, 56));
        for (uint256 i; i < 4; ++i) {
            w.plyr[i].inGame = i == 0;
            w.plyr[i].score = 100 + int32(uint32(i));
            for (uint256 j; j < 4; ++j) {
                w.plyr[i].frags[j] = int32(uint32(i * 4 + j)) - 5;
            }
        }
        V.V_Init(v);
        M_BBox.M_ClearBox(v.dirtybox);
        WI.WI_Start(s, w, p, a, v, source);
    }

    function action(
        int32[5] memory q,
        WiState memory s,
        WiInput memory p,
        WiGraphics memory a,
        VideoState memory v,
        ResourceView memory source
    ) internal view {
        if (q[0] == 0) {
            if (q[1] < 1 || q[1] > 1000 || q[2] < 0 || q[2] > 255) revert InvalidFixture();
            p.buttons[0] = uint8(uint32(q[2]));
            for (int32 i; i < q[1]; ++i) {
                WI.WI_Ticker(s, p);
            }
            if (q[3] != 0) WI.WI_Drawer(s, a, v);
        } else if (q[0] == 1) {
            WI.WI_Drawer(s, a, v);
        } else if (q[0] == 2) {
            WiStart memory w = s.wbs;
            w.last = q[1];
            w.next = q[2];
            w.didsecret = q[3] != 0;
            WI.WI_Start(s, w, p, a, v, source);
        } else if (q[0] == 3) {
            WI.WI_drawNum(a, v, q[1], q[2], q[3], q[4]);
        } else if (q[0] == 4) {
            WI.WI_drawPercent(a, v, q[1], q[2], q[3]);
        } else if (q[0] == 5) {
            WI.WI_drawTime(a, v, q[1], q[2], q[3]);
        } else if (q[0] == 6) {
            bytes[] memory candidates = new bytes[](2);
            candidates[0] = a.yah[0];
            candidates[1] = a.yah[1];
            WI.WI_drawOnLnode(q[1], candidates, v);
        } else if (q[0] == 7) {
            WI.WI_drawAnimatedBack(s, a, v);
        } else {
            revert InvalidFixture();
        }
    }

    function stateBytes(WiState memory s, WiInput memory p) internal pure returns (bytes memory result) {
        int32[113] memory w;
        uint256 n;
        w[n++] = s.wbs.epsd;
        w[n++] = s.wbs.didsecret ? int32(1) : int32(0);
        w[n++] = s.wbs.last;
        w[n++] = s.wbs.next;
        w[n++] = s.wbs.maxkills;
        w[n++] = s.wbs.maxitems;
        w[n++] = s.wbs.maxsecret;
        w[n++] = s.wbs.maxfrags;
        w[n++] = s.wbs.partime;
        w[n++] = s.wbs.pnum;
        for (uint256 i; i < 4; ++i) {
            w[n++] = s.wbs.plyr[i].inGame ? int32(1) : int32(0);
            w[n++] = s.wbs.plyr[i].skills;
            w[n++] = s.wbs.plyr[i].sitems;
            w[n++] = s.wbs.plyr[i].ssecret;
            w[n++] = s.wbs.plyr[i].stime;
            for (uint256 j; j < 4; ++j) {
                w[n++] = s.wbs.plyr[i].frags[j];
            }
            w[n++] = s.wbs.plyr[i].score;
        }
        w[n++] = s.state;
        w[n++] = s.acceleratestage;
        w[n++] = s.me;
        w[n++] = s.cnt;
        w[n++] = s.bcnt;
        w[n++] = s.firstrefresh;
        for (uint256 i; i < 4; ++i) {
            w[n++] = s.cnt_kills[i];
        }
        for (uint256 i; i < 4; ++i) {
            w[n++] = s.cnt_items[i];
        }
        for (uint256 i; i < 4; ++i) {
            w[n++] = s.cnt_secret[i];
        }
        w[n++] = s.cnt_time;
        w[n++] = s.cnt_par;
        w[n++] = s.cnt_pause;
        w[n++] = s.sp_state;
        w[n++] = s.snl_pointeron ? int32(1) : int32(0);
        for (uint256 i; i < 10; ++i) {
            w[n++] = s.animNexttic[i];
        }
        for (uint256 i; i < 10; ++i) {
            w[n++] = s.animCtr[i];
        }
        w[n++] = s.started ? int32(1) : int32(0);
        w[n++] = s.worldDoneRequested ? int32(1) : int32(0);
        w[n++] = p.gamemode;
        for (uint256 i; i < 4; ++i) {
            w[n++] = p.playeringame[i] ? int32(1) : int32(0);
        }
        for (uint256 i; i < 4; ++i) {
            w[n++] = int32(uint32(p.buttons[i]));
        }
        for (uint256 i; i < 4; ++i) {
            w[n++] = p.attackdown[i];
        }
        for (uint256 i; i < 4; ++i) {
            w[n++] = p.usedown[i];
        }
        w[n++] = int32(p.rndindex);
        assert(n == 113);
        result = new bytes(452);
        for (uint256 i; i < 113; ++i) {
            uint32 value = uint32(w[i]);
            uint256 cursor = i * 4;
            result[cursor] = bytes1(uint8(value >> 24));
            result[cursor + 1] = bytes1(uint8(value >> 16));
            result[cursor + 2] = bytes1(uint8(value >> 8));
            result[cursor + 3] = bytes1(uint8(value));
        }
    }

    function capture(bytes memory output, uint256 i, WiState memory s, WiInput memory p, VideoState memory v)
        internal
        pure
    {
        putHash(output, i * 128, sha256(stateBytes(s, p)));
        putHash(
            output,
            i * 128 + 32,
            sha256(abi.encodePacked(v.dirtybox[0], v.dirtybox[1], v.dirtybox[2], v.dirtybox[3]))
        );
        putHash(output, i * 128 + 64, sha256(v.screens[0]));
        putHash(output, i * 128 + 96, sha256(v.screens[1]));
    }

    function putHash(bytes memory output, uint256 cursor, bytes32 value) internal pure {
        if (cursor + 32 > output.length) revert InvalidFixture();
        // Entire 32-byte write is inside the checked allocated bytes payload.
        assembly ("memory-safe") { mstore(add(add(output, 32), cursor), value) }
    }
}
