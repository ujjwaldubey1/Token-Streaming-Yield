// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title StreamYieldBase
    @author BLOK Capital DAO
    @notice Base contract for StreamYieldFacet exposing yield-streaming functions
    @dev This base contract provides common functionality for StreamYieldFacet, including
         deposit, withdrawal, and yield calculation logic. It uses SafeERC20 for
         secure token transfers.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Contracts
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Local Interfaces
import {IStreamYield} from "src/facets/utilityFacets/IStreamYield.sol";

// Local Libraries
import {StreamYieldStorage} from "src/facets/utilityFacets/StreamYieldStorage.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when token address is zero
error StreamYieldFacet_InvalidToken();

/// @notice Thrown when amount is zero
error StreamYieldFacet_InvalidAmount();

/// @notice Thrown when user has insufficient balance for withdrawal
error StreamYieldFacet_InsufficientBalance();

/// @notice Thrown when deposit is locked
error StreamYieldFacet_DepositLocked();

/// @notice Thrown when APR exceeds maximum allowed
error StreamYieldFacet_APRTooHigh();

abstract contract StreamYieldBase is IStreamYield {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice Basis points denominator (10000 = 100%)
    uint256 private constant BASIS_POINTS = 10000;

    /// @notice Seconds in a year for APR calculation
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /// @notice Maximum APR in basis points (100% = 10000 basis points)
    uint256 private constant MAX_APR_BASIS_POINTS = 10000;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when tokens are deposited
    /// @param user The user address that deposited
    /// @param token The token address that was deposited
    /// @param amount The amount of tokens deposited
    event StreamYieldDeposited(address indexed user, address indexed token, uint256 amount);

    /// @notice Emitted when tokens are withdrawn
    /// @param user The user address that withdrew
    /// @param token The token address that was withdrawn
    /// @param principal The principal amount withdrawn
    /// @param yield The yield amount withdrawn
    event StreamYieldWithdrawn(address indexed user, address indexed token, uint256 principal, uint256 yield);

    /// @notice Emitted when a lock is set on a deposit
    /// @param user The user address
    /// @param token The token address
    /// @param lockExpiry The timestamp when the lock expires
    event StreamYieldLockSet(address indexed user, address indexed token, uint256 lockExpiry);

    /// @notice Emitted when APR is updated
    /// @param oldAPR The old APR in basis points
    /// @param newAPR The new APR in basis points
    event StreamYieldAPRUpdated(uint256 oldAPR, uint256 newAPR);

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /// @notice Calculates the accrued yield for a user
    /// @param user The user address
    /// @param token The token address
    /// @return The total accrued yield
    function _calculateYield(address user, address token) internal view returns (uint256) {
        StreamYieldStorage.Layout storage s = StreamYieldStorage.layout();
        StreamYieldStorage.UserDeposit storage userDeposit = s.deposits[user][token];

        if (userDeposit.principal == 0) {
            return userDeposit.accruedYield;
        }

        uint256 timeElapsed = block.timestamp - userDeposit.lastUpdateTime;
        uint256 yieldAccrued =
            (userDeposit.principal * s.aprBasisPoints * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);

        return userDeposit.accruedYield + yieldAccrued;
    }

    /// @notice Updates the accrued yield for a user
    /// @param user The user address
    /// @param token The token address
    function _updateYield(address user, address token) internal {
        StreamYieldStorage.Layout storage s = StreamYieldStorage.layout();
        StreamYieldStorage.UserDeposit storage userDeposit = s.deposits[user][token];

        if (userDeposit.principal > 0) {
            userDeposit.accruedYield = _calculateYield(user, token);
            userDeposit.lastUpdateTime = block.timestamp;
        }
    }

    /// @notice Deposits tokens into the yield-streaming system
    /// @param user The user address
    /// @param token The ERC20 token address to deposit
    /// @param amount Amount of tokens to deposit
    function _deposit(address user, address token, uint256 amount) internal {
        if (token == address(0)) {
            revert StreamYieldFacet_InvalidToken();
        }
        if (amount == 0) {
            revert StreamYieldFacet_InvalidAmount();
        }

        StreamYieldStorage.Layout storage s = StreamYieldStorage.layout();
        StreamYieldStorage.UserDeposit storage userDeposit = s.deposits[user][token];

        // Update yield before modifying principal
        _updateYield(user, token);

        // Transfer tokens from user to contract
        IERC20(token).safeTransferFrom(user, address(this), amount);

        // Update deposit info
        userDeposit.principal += amount;
        if (userDeposit.lastUpdateTime == 0) {
            userDeposit.lastUpdateTime = block.timestamp;
        }

        // Update total deposits
        s.totalDeposits[token] += amount;

        emit StreamYieldDeposited(user, token, amount);
    }

    /// @notice Withdraws tokens and accrued yield from the system
    /// @param user The user address
    /// @param token The ERC20 token address to withdraw
    /// @param amount Amount of principal to withdraw
    function _withdraw(address user, address token, uint256 amount) internal {
        if (token == address(0)) {
            revert StreamYieldFacet_InvalidToken();
        }
        if (amount == 0) {
            revert StreamYieldFacet_InvalidAmount();
        }

        StreamYieldStorage.Layout storage s = StreamYieldStorage.layout();
        StreamYieldStorage.UserDeposit storage userDeposit = s.deposits[user][token];

        // Check lock
        if (block.timestamp < userDeposit.lockExpiry) {
            revert StreamYieldFacet_DepositLocked();
        }

        // Update yield before withdrawal
        _updateYield(user, token);

        // Check balance
        if (userDeposit.principal < amount) {
            revert StreamYieldFacet_InsufficientBalance();
        }

        // Calculate total amount to withdraw (principal + all accrued yield)
        uint256 yieldToWithdraw = userDeposit.accruedYield;
        uint256 totalToWithdraw = amount + yieldToWithdraw;

        // Update state
        userDeposit.principal -= amount;
        userDeposit.accruedYield = 0;

        if (userDeposit.principal == 0) {
            userDeposit.lastUpdateTime = 0;
            userDeposit.lockExpiry = 0;
        }

        // Update total deposits
        s.totalDeposits[token] -= amount;

        // Transfer tokens back to user
        IERC20(token).safeTransfer(user, totalToWithdraw);

        emit StreamYieldWithdrawn(user, token, amount, yieldToWithdraw);
    }

    /// @notice Gets the current balance including accrued yield for a user
    /// @param user The user address
    /// @param token The token address
    /// @return principal The principal amount deposited
    /// @return accruedYield The total accrued yield
    /// @return totalBalance The total balance (principal + yield)
    function _getBalance(address user, address token)
        internal
        view
        returns (uint256 principal, uint256 accruedYield, uint256 totalBalance)
    {
        StreamYieldStorage.Layout storage s = StreamYieldStorage.layout();
        StreamYieldStorage.UserDeposit storage userDeposit = s.deposits[user][token];

        principal = userDeposit.principal;
        accruedYield = _calculateYield(user, token);
        totalBalance = principal + accruedYield;
    }

    /// @notice Sets a lock on the user's deposit
    /// @param user The user address
    /// @param token The token address
    /// @param lockDuration Duration in seconds to lock the deposit
    function _setLock(address user, address token, uint256 lockDuration) internal {
        StreamYieldStorage.Layout storage s = StreamYieldStorage.layout();
        StreamYieldStorage.UserDeposit storage userDeposit = s.deposits[user][token];

        uint256 lockExpiry = block.timestamp + lockDuration;
        userDeposit.lockExpiry = lockExpiry;

        emit StreamYieldLockSet(user, token, lockExpiry);
    }

    /// @notice Sets the APR for yield accrual
    /// @param aprBasisPoints The APR in basis points (e.g., 500 = 5%)
    function _setAPR(uint256 aprBasisPoints) internal {
        if (aprBasisPoints > MAX_APR_BASIS_POINTS) {
            revert StreamYieldFacet_APRTooHigh();
        }

        StreamYieldStorage.Layout storage s = StreamYieldStorage.layout();
        uint256 oldAPR = s.aprBasisPoints;
        s.aprBasisPoints = aprBasisPoints;

        emit StreamYieldAPRUpdated(oldAPR, aprBasisPoints);
    }

    /// @notice Gets the current APR
    /// @return The APR in basis points
    function _getAPR() internal view returns (uint256) {
        return StreamYieldStorage.layout().aprBasisPoints;
    }
}

