// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract RPSToken is ERC20 {
    constructor(uint256 _totalSupply) ERC20("RockPaperScissors", "RPS", 18) {
        _mint(msg.sender, _totalSupply * 1e18);
    }
}
