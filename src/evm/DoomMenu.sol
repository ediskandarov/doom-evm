// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {M_Menu, MenuState} from "../doom/m_menu.sol";

/// @notice D_ProcessEvents menu-first dispatch for the production packet boundary.
library DoomMenu {
    error InvalidKeyboardEvents();

    /// @dev Validate the entire packet before responders. If any event belongs to
    /// the menu, reserve the packet for the menu: no letters reach ST cheats, no
    /// navigation reaches movement/weapons. Remaining events after startup are
    /// discarded. The caller clears held gameplay keys at this ownership boundary.
    /// Unknown keys and keyups remain original false-return cases in M_Responder;
    /// this deliberate adapter isolation consumes them while the menu owns input.
    function respond(MenuState memory m, bytes memory events, bool gameStarted)
        internal pure returns (bool intercepted)
    {
        if (events.length > 128 || events.length % 2 != 0) revert InvalidKeyboardEvents();
        for (uint256 i; i < events.length; i += 2) {
            if (uint8(events[i]) > 1) revert InvalidKeyboardEvents();
        }
        intercepted = m.menuactive || m.messageToPrint || !gameStarted;
        for (uint256 i; i < events.length; i += 2) {
            int32 kind = int32(uint32(uint8(events[i])));
            int32 key = int32(uint32(uint8(events[i + 1])));
            // Original G_Responder opens the control panel on title/demo input.
            if (!gameStarted && !m.menuactive && !m.messageToPrint && kind == 0 && key != 27) {
                M_Menu.M_StartControlPanel(m);
                intercepted = true;
                continue;
            }
            bool owned = m.menuactive || m.messageToPrint;
            bool consumed = M_Menu.M_Responder(m, kind, key);
            if (owned || consumed || m.menuactive || m.messageToPrint) intercepted = true;
            if (m.startRequested) break;
        }
        M_Menu.M_Ticker(m);
    }
}
