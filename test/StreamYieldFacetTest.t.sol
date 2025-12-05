// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Diamond Contracts
import {Diamond} from "src/Diamond.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/facets/baseFacets/ownership/OwnershipFacet.sol";
import {IDiamondLoupe} from "src/facets/baseFacets/loupe/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {IERC165} from "src/interfaces/IERC165.sol";

// StreamYield Contracts
import {StreamYieldFacet} from "src/facets/utilityFacets/StreamYieldFacet.sol";
import {IStreamYield} from "src/facets/utilityFacets/IStreamYield.sol";

// Mock Token
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
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
    MockERC20 public token;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        streamYieldFacet = new StreamYieldFacet();

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

        // Add StreamYieldFacet via diamondCut
        IDiamondCut.FacetCut[] memory streamYieldCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory streamYieldSelectors = new bytes4[](6);
        streamYieldSelectors[0] = IStreamYield.deposit.selector;
        streamYieldSelectors[1] = IStreamYield.withdraw.selector;
        streamYieldSelectors[2] = IStreamYield.getBalance.selector;
        streamYieldSelectors[3] = IStreamYield.setLock.selector;
        streamYieldSelectors[4] = IStreamYield.setAPR.selector;
        streamYieldSelectors[5] = IStreamYield.getAPR.selector;

        streamYieldCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(streamYieldFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: streamYieldSelectors
        });

        DiamondCutFacet(address(diamond)).diamondCut(streamYieldCuts, address(0), "");

        // Deploy mock token
        token = new MockERC20("Mock Token", "MOCK");

        // Set APR to 5% (500 basis points)
        IStreamYield(address(diamond)).setAPR(500);

        // Mint tokens to users
        token.mint(user1, 10000 * 10 ** 18);
        token.mint(user2, 10000 * 10 ** 18);
    }

    function testDeposit() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);
        IStreamYield(address(diamond)).deposit(address(token), depositAmount);
        vm.stopPrank();

        (uint256 principal, uint256 accruedYield, uint256 totalBalance) =
            IStreamYield(address(diamond)).getBalance(user1, address(token));

        assertEq(principal, depositAmount);
        assertEq(accruedYield, 0);
        assertEq(totalBalance, depositAmount);
    }

    function testYieldAccrual() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);
        IStreamYield(address(diamond)).deposit(address(token), depositAmount);
        vm.stopPrank();

        // Warp forward 365 days (1 year)
        vm.warp(block.timestamp + 365 days);

        (uint256 principal, uint256 accruedYield, uint256 totalBalance) =
            IStreamYield(address(diamond)).getBalance(user1, address(token));

        // At 5% APR for 1 year, yield should be 50 tokens
        uint256 expectedYield = (depositAmount * 500) / 10000;
        assertEq(principal, depositAmount);
        assertEq(accruedYield, expectedYield);
        assertEq(totalBalance, depositAmount + expectedYield);
    }

    function testYieldAccrualPartialYear() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);
        IStreamYield(address(diamond)).deposit(address(token), depositAmount);
        vm.stopPrank();

        // Warp forward 182.5 days (half year)
        vm.warp(block.timestamp + 182.5 days);

        (uint256 principal, uint256 accruedYield, uint256 totalBalance) =
            IStreamYield(address(diamond)).getBalance(user1, address(token));

        // At 5% APR for 0.5 year, yield should be approximately 25 tokens
        uint256 expectedYield = (depositAmount * 500 * 182.5 days) / (10000 * 365 days);
        assertEq(principal, depositAmount);
        assertApproxEqAbs(accruedYield, expectedYield, 1e15); // Allow small rounding error
        assertApproxEqAbs(totalBalance, depositAmount + expectedYield, 1e15);
    }

    function testWithdraw() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 withdrawAmount = 500 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);
        IStreamYield(address(diamond)).deposit(address(token), depositAmount);

        // Warp forward 365 days
        vm.warp(block.timestamp + 365 days);

        uint256 balanceBefore = token.balanceOf(user1);
        IStreamYield(address(diamond)).withdraw(address(token), withdrawAmount);
        uint256 balanceAfter = token.balanceOf(user1);
        vm.stopPrank();

        // User should receive withdrawn principal + all accrued yield
        uint256 expectedYield = (depositAmount * 500) / 10000;
        uint256 expectedReceived = withdrawAmount + expectedYield;
        assertEq(balanceAfter - balanceBefore, expectedReceived);

        // Remaining balance
        (uint256 principal, uint256 accruedYield, uint256 totalBalance) =
            IStreamYield(address(diamond)).getBalance(user1, address(token));

        assertEq(principal, depositAmount - withdrawAmount);
        assertEq(accruedYield, 0); // Yield was withdrawn
        assertEq(totalBalance, depositAmount - withdrawAmount);
    }

    function testWithdrawAll() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);
        IStreamYield(address(diamond)).deposit(address(token), depositAmount);

        // Warp forward 365 days
        vm.warp(block.timestamp + 365 days);

        uint256 balanceBefore = token.balanceOf(user1);
        IStreamYield(address(diamond)).withdraw(address(token), depositAmount);
        uint256 balanceAfter = token.balanceOf(user1);
        vm.stopPrank();

        // User should receive all principal + all accrued yield
        uint256 expectedYield = (depositAmount * 500) / 10000;
        uint256 expectedReceived = depositAmount + expectedYield;
        assertEq(balanceAfter - balanceBefore, expectedReceived);

        // Balance should be zero
        (uint256 principal, uint256 accruedYield, uint256 totalBalance) =
            IStreamYield(address(diamond)).getBalance(user1, address(token));

        assertEq(principal, 0);
        assertEq(accruedYield, 0);
        assertEq(totalBalance, 0);
    }

    function testSetLockAndWithdrawFails() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 lockDuration = 365 days;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);
        IStreamYield(address(diamond)).deposit(address(token), depositAmount);

        // Set lock for 1 year
        IStreamYield(address(diamond)).setLock(address(token), lockDuration);

        // Try to withdraw immediately (should fail)
        vm.expectRevert();
        IStreamYield(address(diamond)).withdraw(address(token), depositAmount);
        vm.stopPrank();
    }

    function testSetLockAndWithdrawAfterExpiry() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 lockDuration = 365 days;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);
        IStreamYield(address(diamond)).deposit(address(token), depositAmount);

        // Set lock for 1 year
        IStreamYield(address(diamond)).setLock(address(token), lockDuration);

        // Warp forward past lock expiry
        vm.warp(block.timestamp + lockDuration + 1);

        // Withdraw should succeed now
        IStreamYield(address(diamond)).withdraw(address(token), depositAmount);
        vm.stopPrank();

        (uint256 principal,,) = IStreamYield(address(diamond)).getBalance(user1, address(token));
        assertEq(principal, 0);
    }

    function testSetAPR() public {
        uint256 newAPR = 1000; // 10%
        IStreamYield(address(diamond)).setAPR(newAPR);

        uint256 currentAPR = IStreamYield(address(diamond)).getAPR();
        assertEq(currentAPR, newAPR);
    }

    function testSetAPROnlyOwner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        IStreamYield(address(diamond)).setAPR(1000);
        vm.stopPrank();
    }

    function testMultipleDeposits() public {
        uint256 depositAmount1 = 1000 * 10 ** 18;
        uint256 depositAmount2 = 500 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount1 + depositAmount2);

        IStreamYield(address(diamond)).deposit(address(token), depositAmount1);

        // Warp forward 182.5 days
        vm.warp(block.timestamp + 182.5 days);

        IStreamYield(address(diamond)).deposit(address(token), depositAmount2);
        vm.stopPrank();

        (uint256 principal, uint256 accruedYield, uint256 totalBalance) =
            IStreamYield(address(diamond)).getBalance(user1, address(token));

        assertEq(principal, depositAmount1 + depositAmount2);
        // Yield should be calculated based on first deposit for half year
        uint256 expectedYield = (depositAmount1 * 500 * 182.5 days) / (10000 * 365 days);
        assertApproxEqAbs(accruedYield, expectedYield, 1e15);
        assertApproxEqAbs(totalBalance, principal + expectedYield, 1e15);
    }

    function testGetBalanceWithNoDeposit() public {
        (uint256 principal, uint256 accruedYield, uint256 totalBalance) =
            IStreamYield(address(diamond)).getBalance(user1, address(token));

        assertEq(principal, 0);
        assertEq(accruedYield, 0);
        assertEq(totalBalance, 0);
    }

    function testDepositZeroAmountFails() public {
        vm.startPrank(user1);
        vm.expectRevert();
        IStreamYield(address(diamond)).deposit(address(token), 0);
        vm.stopPrank();
    }

    function testWithdrawZeroAmountFails() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);
        IStreamYield(address(diamond)).deposit(address(token), depositAmount);

        vm.expectRevert();
        IStreamYield(address(diamond)).withdraw(address(token), 0);
        vm.stopPrank();
    }

    function testWithdrawMoreThanBalanceFails() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 withdrawAmount = 2000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(diamond), depositAmount);
        IStreamYield(address(diamond)).deposit(address(token), depositAmount);

        vm.expectRevert();
        IStreamYield(address(diamond)).withdraw(address(token), withdrawAmount);
        vm.stopPrank();
    }
}

