//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script} from "lib/forge-std/src/Script.sol";
import {VmSafe} from "lib/forge-std/src/Vm.sol";
import {DSC} from "../src/DSC.sol";
import {DSCengine} from "../src/DSCengine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract deployDSC is Script {
    address[] private tokenAddresses;
    address[] private pricefeedAddresses;

    function run() external returns (DSC, DSCengine, HelperConfig) {
      
        HelperConfig helperconfig = new HelperConfig();
        (
            address wethUSD_pricefeed_address,
            address wbtcUSD_pricefeed_address,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = helperconfig.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        pricefeedAddresses = [wethUSD_pricefeed_address, wbtcUSD_pricefeed_address];
        DSC dsc = new DSC();
        DSCengine dscEngine = new DSCengine(tokenAddresses,pricefeedAddresses,address(dsc));
        dsc.transferOwnership(address(dscEngine));
       
        return (dsc, dscEngine, helperconfig);
    }
}
