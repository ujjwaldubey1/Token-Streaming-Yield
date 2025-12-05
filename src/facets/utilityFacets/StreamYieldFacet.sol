// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*###############################################################################

    @title StreamYieldFacet
    @author BLOK Capital DAO
    @notice Facet exposing StreamYield integration functions (deposit / withdraw / balance / lock)
    @dev This facet provides a yield-streaming system where users can deposit tokens
         and earn yield continuously based on time elapsed

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import {Facet} from "../Facet.sol";
import {StreamYieldStorage} from "./StreamYieldStorage.sol";
import {StreamYieldBase} from "./StreamYieldBase.sol";
import {IStreamYield} from "./IStreamYield.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StreamYieldFacet is Facet, StreamYieldBase, IStreamYield {
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event LockSet(address indexed user, address indexed token, uint256 expiry);

    function deposit(address token, uint256 amount, uint256 aprBps) external nonReentrant {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be greater than 0");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        StreamYieldStorage.Stream storage s = StreamYieldStorage.layout().streams[msg.sender][token];

        if (s.lastUpdated != 0) {
            _applyYield(s);
        }

        s.principal += amount;

        if (s.lastUpdated == 0) {
            s.lastUpdated = block.timestamp;
        }

        if (s.aprBps == 0) {
            s.aprBps = aprBps;
        }

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be greater than 0");

        StreamYieldStorage.Stream storage s = StreamYieldStorage.layout().streams[msg.sender][token];

        _applyYield(s);

        require(s.principal >= amount, "Insufficient balance");

        if (s.locked && block.timestamp < s.lockExpiry) {
            revert("Deposit is locked");
        }

        s.principal -= amount;

        IERC20(token).transfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    function getBalance(address user, address token) external view returns (uint256) {
        StreamYieldStorage.Stream storage s = StreamYieldStorage.layout().streams[user][token];
        return s.principal + _accruedSince(s);
    }

    function setLock(address token, uint256 durationSeconds) external nonReentrant {
        require(token != address(0), "Invalid token");
        require(durationSeconds > 0, "Duration must be greater than 0");

        StreamYieldStorage.Stream storage s = StreamYieldStorage.layout().streams[msg.sender][token];

        s.locked = true;
        s.lockExpiry = block.timestamp + durationSeconds;

        emit LockSet(msg.sender, token, s.lockExpiry);
    }

    function setApr(address token, uint256 aprBps) external nonReentrant {
        require(token != address(0), "Invalid token");

        StreamYieldStorage.Stream storage s = StreamYieldStorage.layout().streams[msg.sender][token];

        s.aprBps = aprBps;
    }
}
