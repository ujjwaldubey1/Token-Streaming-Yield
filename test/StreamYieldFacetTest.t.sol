// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Diamond} from "../src/Diamond.sol";
import {IDiamondCut} from "../src/facets/baseFacets/cut/IDiamondCut.sol";
import {DiamondCutFacet} from "../src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {IDiamondLoupe} from "../src/facets/baseFacets/loupe/IDiamondLoupe.sol";
import {OwnershipFacet} from "../src/facets/baseFacets/ownership/OwnershipFacet.sol";
import {IERC173} from "../src/interfaces/IERC173.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";

import {StreamYieldFacet} from "../src/facets/utilityFacets/StreamYieldFacet.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StreamYieldFacetTest is Test {
    Diamond public diamond;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    StreamYieldFacet public streamYieldFacet;
    ERC20Mock public token;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        // Deploy base facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();

        // Build facet cuts for diamond constructor
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](3);

        // DiamondCutFacet
        bytes4[] memory cutFunctionSelectors = new bytes4[](1);
        cutFunctionSelectors[0] = IDiamondCut.diamondCut.selector;
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutFunctionSelectors
        });

        // DiamondLoupeFacet
        bytes4[] memory loupeFunctionSelectors = new bytes4[](5);
        loupeFunctionSelectors[0] = IDiamondLoupe.facets.selector;
        loupeFunctionSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        loupeFunctionSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        loupeFunctionSelectors[3] = IDiamondLoupe.facetAddress.selector;
        loupeFunctionSelectors[4] = IERC165.supportsInterface.selector;
        facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeFunctionSelectors
        });

        // OwnershipFacet
        bytes4[] memory ownershipFunctionSelectors = new bytes4[](2);
        ownershipFunctionSelectors[0] = IERC173.owner.selector;
        ownershipFunctionSelectors[1] = IERC173.transferOwnership.selector;
        facetCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipFunctionSelectors
        });

        // Deploy diamond
        diamond = new Diamond(owner, facetCuts);

        // Deploy mock token
        token = new ERC20Mock("Mock Token", "MOCK");

        // Mint tokens to users
        token.mint(user1, 10000 * 10 ** 18);
        token.mint(user2, 10000 * 10 ** 18);

        // Deploy StreamYieldFacet
        streamYieldFacet = new StreamYieldFacet();

        // Add StreamYieldFacet via diamondCut
        IDiamondCut.FacetCut[] memory streamYieldCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory streamYieldSelectors = new bytes4[](5);
        streamYieldSelectors[0] = StreamYieldFacet.deposit.selector;
        streamYieldSelectors[1] = StreamYieldFacet.withdraw.selector;
        streamYieldSelectors[2] = StreamYieldFacet.getBalance.selector;
        streamYieldSelectors[3] = StreamYieldFacet.setLock.selector;
        streamYieldSelectors[4] = StreamYieldFacet.setApr.selector;

        streamYieldCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(streamYieldFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: streamYieldSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(streamYieldCuts, address(0), "");
    }

    function testDepositAndInitialBalance() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 aprBps = 500; // 5%

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);

        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), depositAmount, aprBps)
        );
        assertTrue(success, "Deposit failed");

        (bool success2, bytes memory data) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.getBalance.selector, user1, address(token)));
        assertTrue(success2, "GetBalance failed");

        uint256 balance = abi.decode(data, (uint256));
        assertEq(balance, depositAmount, "Initial balance should equal deposit amount");
        vm.stopPrank();
    }

    function testYieldAccrualAfterOneDay() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 aprBps = 500; // 5%

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);

        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), depositAmount, aprBps)
        );
        assertTrue(success, "Deposit failed");
        vm.stopPrank();

        // Warp forward 1 day
        vm.warp(block.timestamp + 1 days);

        (bool success2, bytes memory data) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.getBalance.selector, user1, address(token)));
        assertTrue(success2, "GetBalance failed");

        uint256 balance = abi.decode(data, (uint256));
        assertTrue(balance > depositAmount, "Balance should be greater than deposit after 1 day");

        // Calculate expected yield for 1 day at 5% APR
        uint256 expectedYield = (depositAmount * aprBps * 1 days) / (10000 * 365 days);
        assertApproxEqAbs(balance, depositAmount + expectedYield, 1e10, "Balance should match deposit + expected yield");
    }

    function testPartialWithdrawal() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 withdrawAmount = 400 * 10 ** 18;
        uint256 aprBps = 500; // 5%

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);

        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), depositAmount, aprBps)
        );
        assertTrue(success, "Deposit failed");

        // Warp forward 10 days
        vm.warp(block.timestamp + 10 days);

        uint256 balanceBefore = token.balanceOf(user1);

        (bool success2,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.withdraw.selector, address(token), withdrawAmount)
        );
        assertTrue(success2, "Withdraw failed");

        uint256 balanceAfter = token.balanceOf(user1);

        // User should receive the withdrawn amount
        assertEq(balanceAfter - balanceBefore, withdrawAmount, "User should receive withdrawn amount");

        // Check remaining balance
        (bool success3, bytes memory data) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.getBalance.selector, user1, address(token)));
        assertTrue(success3, "GetBalance failed");

        uint256 remainingBalance = abi.decode(data, (uint256));
        assertEq(remainingBalance, depositAmount - withdrawAmount, "Remaining balance should be deposit - withdrawal");
        vm.stopPrank();
    }

    function testWithdrawAll() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 aprBps = 500; // 5%

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);

        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), depositAmount, aprBps)
        );
        assertTrue(success, "Deposit failed");

        // Warp forward 365 days
        vm.warp(block.timestamp + 365 days);

        uint256 tokenBalanceBefore = token.balanceOf(user1);

        (bool success3,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.withdraw.selector, address(token), depositAmount)
        );
        assertTrue(success3, "Withdraw failed");

        uint256 tokenBalanceAfter = token.balanceOf(user1);

        // User should receive full principal
        assertEq(tokenBalanceAfter - tokenBalanceBefore, depositAmount, "User should receive full principal");

        // Stream principal should be zero
        (bool success4, bytes memory data2) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.getBalance.selector, user1, address(token)));
        assertTrue(success4, "GetBalance failed");

        uint256 remainingBalance = abi.decode(data2, (uint256));
        assertEq(remainingBalance, 0, "Remaining balance should be zero");
        vm.stopPrank();
    }

    function testLockPreventsWithdrawal() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 aprBps = 500; // 5%
        uint256 lockDuration = 30 days;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);

        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), depositAmount, aprBps)
        );
        assertTrue(success, "Deposit failed");

        // Set lock
        (bool success2,) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.setLock.selector, address(token), lockDuration));
        assertTrue(success2, "SetLock failed");

        // Try to withdraw before lock expiry (should fail)
        (bool success3,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.withdraw.selector, address(token), depositAmount)
        );
        assertFalse(success3, "Withdraw should fail when locked");

        // Warp past lock expiry
        vm.warp(block.timestamp + lockDuration + 1);

        // Withdraw should succeed now
        (bool success4,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.withdraw.selector, address(token), depositAmount)
        );
        assertTrue(success4, "Withdraw should succeed after lock expiry");

        vm.stopPrank();
    }

    function testMultipleUsersIndependentStreams() public {
        uint256 depositAmount1 = 1000 * 10 ** 18;
        uint256 depositAmount2 = 500 * 10 ** 18;
        uint256 aprBps = 500; // 5%

        // User1 deposits
        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount1);
        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), depositAmount1, aprBps)
        );
        assertTrue(success, "User1 deposit failed");
        vm.stopPrank();

        // User2 deposits
        vm.startPrank(user2);
        token.approve(address(diamond), depositAmount2);
        (bool success2,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), depositAmount2, aprBps)
        );
        assertTrue(success2, "User2 deposit failed");
        vm.stopPrank();

        // Warp forward
        vm.warp(block.timestamp + 10 days);

        // Check user1 balance
        (bool success3, bytes memory data1) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.getBalance.selector, user1, address(token)));
        assertTrue(success3, "User1 getBalance failed");
        uint256 balance1 = abi.decode(data1, (uint256));

        // Check user2 balance
        (bool success4, bytes memory data2) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.getBalance.selector, user2, address(token)));
        assertTrue(success4, "User2 getBalance failed");
        uint256 balance2 = abi.decode(data2, (uint256));

        // Verify balances are independent and correct
        assertTrue(balance1 > depositAmount1, "User1 balance should include yield");
        assertTrue(balance2 > depositAmount2, "User2 balance should include yield");
        assertTrue(balance1 > balance2, "User1 balance should be higher due to larger deposit");
    }

    function testSetAprUpdatesYieldRate() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 aprBps1 = 500; // 5%
        uint256 aprBps2 = 1000; // 10%

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);

        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), depositAmount, aprBps1)
        );
        assertTrue(success, "Deposit failed");

        // Warp forward 10 days
        vm.warp(block.timestamp + 10 days);

        // Change APR
        (bool success2,) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.setApr.selector, address(token), aprBps2));
        assertTrue(success2, "SetApr failed");

        // Warp forward another 10 days
        vm.warp(block.timestamp + 10 days);

        (bool success3, bytes memory data) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.getBalance.selector, user1, address(token)));
        assertTrue(success3, "GetBalance failed");

        uint256 balance = abi.decode(data, (uint256));
        assertTrue(balance > depositAmount, "Balance should include accrued yield");

        vm.stopPrank();
    }

    function testDepositWithZeroAmountFails() public {
        uint256 aprBps = 500;

        vm.startPrank(user1);
        token.approve(address(diamond), 1000 * 10 ** 18);

        (bool success,) =
            address(diamond).call(abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), 0, aprBps));
        assertFalse(success, "Deposit with zero amount should fail");

        vm.stopPrank();
    }

    function testWithdrawMoreThanBalanceFails() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 withdrawAmount = 2000 * 10 ** 18;
        uint256 aprBps = 500;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);

        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.deposit.selector, address(token), depositAmount, aprBps)
        );
        assertTrue(success, "Deposit failed");

        (bool success2,) = address(diamond).call(
            abi.encodeWithSelector(StreamYieldFacet.withdraw.selector, address(token), withdrawAmount)
        );
        assertFalse(success2, "Withdraw more than balance should fail");

        vm.stopPrank();
    }
}
