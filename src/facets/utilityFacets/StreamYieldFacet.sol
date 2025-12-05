// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title StreamYieldFacet
    @author BLOK Capital DAO
    @notice Facet exposing StreamYield integration functions (deposit / withdraw / balance / lock)
    @dev This facet provides a yield-streaming system where users can deposit tokens
         and earn yield continuously based on time elapsed

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

// Local Contracts
import {StreamYieldBase} from "src/facets/utilityFacets/StreamYieldBase.sol";
import {Facet} from "src/facets/Facet.sol";

// ============================================================================
// StreamYieldFacet
// ============================================================================

contract StreamYieldFacet is StreamYieldBase, Facet {
    using SafeERC20 for IERC20;

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @notice Gets the current balance including accrued yield for a user
    /// @param user The user address
    /// @param token The token address
    /// @return principal The principal amount deposited
    /// @return accruedYield The total accrued yield
    /// @return totalBalance The total balance (principal + yield)
    function getBalance(address user, address token)
        external
        view
        returns (uint256 principal, uint256 accruedYield, uint256 totalBalance)
    {
        return _getBalance(user, token);
    }

    /// @notice Gets the current APR
    /// @return The APR in basis points
    function getAPR() external view returns (uint256) {
        return _getAPR();
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @notice Deposits tokens into the yield-streaming system
    /// @param token The ERC20 token address to deposit
    /// @param amount Amount of tokens to deposit
    function deposit(address token, uint256 amount) external nonReentrant {
        _deposit(msg.sender, token, amount);
    }

    /// @notice Withdraws tokens and accrued yield from the system
    /// @param token The ERC20 token address to withdraw
    /// @param amount Amount of principal to withdraw
    function withdraw(address token, uint256 amount) external nonReentrant {
        _withdraw(msg.sender, token, amount);
    }

    /// @notice Sets a lock on the user's deposit
    /// @param token The token address
    /// @param lockDuration Duration in seconds to lock the deposit
    function setLock(address token, uint256 lockDuration) external nonReentrant {
        _setLock(msg.sender, token, lockDuration);
    }

    /// @notice Sets the APR for yield accrual (owner only)
    /// @param aprBasisPoints The APR in basis points (e.g., 500 = 5%)
    function setAPR(uint256 aprBasisPoints) external onlyDiamondOwner nonReentrant {
        _setAPR(aprBasisPoints);
    }
}

