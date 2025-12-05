// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title IStreamYield
    @author BLOK Capital DAO
    @notice Interface for StreamYield protocol integration
    @dev Interface used by the StreamYield facet to manage yield-streaming deposits

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IStreamYield {
    /// @notice Deposits tokens into the yield-streaming system
    /// @param token The ERC20 token address to deposit
    /// @param amount Amount of tokens to deposit
    function deposit(address token, uint256 amount) external;

    /// @notice Withdraws tokens and accrued yield from the system
    /// @param token The ERC20 token address to withdraw
    /// @param amount Amount of principal to withdraw
    function withdraw(address token, uint256 amount) external;

    /// @notice Gets the current balance including accrued yield for a user
    /// @param user The user address
    /// @param token The token address
    /// @return principal The principal amount deposited
    /// @return accruedYield The total accrued yield
    /// @return totalBalance The total balance (principal + yield)
    function getBalance(address user, address token)
        external
        view
        returns (uint256 principal, uint256 accruedYield, uint256 totalBalance);

    /// @notice Sets a lock on the user's deposit
    /// @param token The token address
    /// @param lockDuration Duration in seconds to lock the deposit
    function setLock(address token, uint256 lockDuration) external;

    /// @notice Sets the APR for yield accrual (owner only)
    /// @param aprBasisPoints The APR in basis points (e.g., 500 = 5%)
    function setAPR(uint256 aprBasisPoints) external;

    /// @notice Gets the current APR
    /// @return The APR in basis points
    function getAPR() external view returns (uint256);
}

