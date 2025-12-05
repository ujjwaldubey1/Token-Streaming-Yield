//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseScript} from "script/Base.s.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {AaveV3Facet} from "src/facets/utilityFacets/aaveV3/AaveV3Facet.sol";
import {StreamYieldFacet} from "src/facets/utilityFacets/StreamYieldFacet.sol";

contract DeployFacetScript is BaseScript {
    address internal constant DIAMOND_ADDRESS = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;

    function run() public broadcaster {
        setUp();
        // Deploy AaveV3Facet
        AaveV3Facet aaveV3Facet = new AaveV3Facet();

        // Add AaveV3Facet to diamond
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);

        // Add function selectors to AaveV3Facet
        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = AaveV3Facet.getReserveData.selector;
        functionSelectors[1] = AaveV3Facet.lend.selector;
        functionSelectors[2] = AaveV3Facet.withdraw.selector;

        // Add AaveV3Facet to diamond
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(aaveV3Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // Cut diamond
        DiamondCutFacet(DIAMOND_ADDRESS).diamondCut(facetCuts, address(0), "");
        console.log("AaveV3Facet deployed to: ", address(aaveV3Facet));
    }
}

contract DeployStreamYieldFacet is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");

        StreamYieldFacet facet = new StreamYieldFacet();

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = StreamYieldFacet.deposit.selector;
        selectors[1] = StreamYieldFacet.withdraw.selector;
        selectors[2] = StreamYieldFacet.getBalance.selector;
        selectors[3] = StreamYieldFacet.setLock.selector;
        selectors[4] = StreamYieldFacet.setApr.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut(diamondAddress).diamondCut(cut, address(0), "");

        console.log("StreamYieldFacet deployed to:", address(facet));

        vm.stopBroadcast();
    }
}
