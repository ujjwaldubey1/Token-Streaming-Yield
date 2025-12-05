// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*###############################################################################

    @title StreamYieldBase
    @author BLOK Capital DAO
    @notice Base contract for StreamYieldFacet exposing yield-streaming functions
    @dev This base contract provides common functionality for StreamYieldFacet, including
         deposit, withdrawal, and yield calculation logic.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import {StreamYieldStorage} from "./StreamYieldStorage.sol";

abstract contract StreamYieldBase {
    uint256 internal constant SECONDS_PER_YEAR = 365 days;
    uint256 internal constant BASIS_POINTS = 10000;

    function _accruedSince(StreamYieldStorage.Stream storage s) internal view returns (uint256) {
        if (s.principal == 0 || s.lastUpdated == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - s.lastUpdated;
        return (s.principal * s.aprBps * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
    }

    function _applyYield(StreamYieldStorage.Stream storage s) internal {
        if (s.principal > 0 && s.lastUpdated > 0) {
            uint256 yield = _accruedSince(s);
            s.principal += yield;
            s.lastUpdated = block.timestamp;
        }
    }
}
