// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract TokenTimelock {
    uint public constant duration = 40 days;
    uint public immutable end;
    address payable public immutable owner;

    constructor(address payable _owner) public {
        end = block.timestamp + duration;
        owner = _owner;
    }

    function deposit(address token, uint amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    receive() external payable {}

    function withdraw(address token, uint amount) external {
        require(msg.sender == owner, 'only owner');
        require(block.timestamp >= end, 'too early');

        if (token == address(0)) {
            owner.transfer(amount);
        } else {
            IERC20(token).transfer(owner, amount);
        }
    }
}
