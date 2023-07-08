//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract mockWeth is ERC20 {
    constructor(address to, uint256 amount) ERC20("MOCKWETH", "MWETH") {
        _mint(to, amount);
    }
}
