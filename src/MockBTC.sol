//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract mockBTC is ERC20 {
    constructor(address to, uint256 amount) ERC20("MOCKBTC", "MBTC") {
        _mint(to, amount);
    }
}
