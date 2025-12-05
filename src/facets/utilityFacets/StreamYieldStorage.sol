// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title StreamYieldStorage
    @author BLOK Capital DAO
    @notice Storage for the StreamYieldFacet
    @dev This storage is used to store the StreamYieldFacet

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library StreamYieldStorage {
    /// @notice Fixed storage slot for StreamYield persistent state.
    bytes32 internal constant STREAM_YIELD_STORAGE_POSITION = keccak256("stream.yield.storage");

    /// @notice User deposit information
    struct UserDeposit {
        uint256 principal;
        uint256 lastUpdateTime;
        uint256 accruedYield;
        uint256 lockExpiry;
    }

    /// @notice Layout for the StreamYieldStorage
    struct Layout {
        /// @notice Mapping from user address to token address to deposit info
        mapping(address => mapping(address => UserDeposit)) deposits;
        /// @notice APR in basis points (e.g., 500 = 5%)
        uint256 aprBasisPoints;
        /// @notice Total deposits per token
        mapping(address => uint256) totalDeposits;
    }

    /// @notice Returns a pointer to the StreamYield storage layout
    /// @return l Storage pointer to the StreamYield Storage struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STREAM_YIELD_STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}

