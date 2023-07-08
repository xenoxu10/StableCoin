//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script} from "lib/forge-std/src/Script.sol";
import {MockV3AggregatorWETH} from "../src/MockbtcAggregator.sol";
import {mockWeth} from "../src/MockERC20.sol";
import {mockBTC} from "../src/MockBTC.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUSD_pricefeed_address;
        address wbtcUSD_pricefeed_address;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

     uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0x1710f020daecca0b56ee836a110e305c7eb88c4b8f58cda3c02cd6d6a275d438;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSeploiaEthconfig();
        } else {
            activeNetworkConfig = getAnvilEthConfig();
        }
    }

    function getSeploiaEthconfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUSD_pricefeed_address: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUSD_pricefeed_address: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            wbtc: 0xFF82bB6DB46Ad45F017e2Dfb478102C7671B13b3,
            deployerKey: vm.envUint("DEFAULT_ANVIL_PRIVATE_KEY")
        });
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        MockV3AggregatorWETH ethUSDpricefeed = new MockV3AggregatorWETH(8,2000e8);
        ERC20Mock weth = new ERC20Mock();
        
        MockV3AggregatorWETH btcUSDpricefeed = new MockV3AggregatorWETH(8,1000e8);
        ERC20Mock btc = new ERC20Mock();
        vm.stopBroadcast();

        return NetworkConfig({
            wethUSD_pricefeed_address: address(ethUSDpricefeed),
            wbtcUSD_pricefeed_address: address(btcUSDpricefeed),
            weth: address(weth),
            wbtc: address(btc),
            deployerKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        });
    }
}
