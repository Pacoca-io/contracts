// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BnbSwap is Ownable {
    using SafeMath for uint256;

    address public oneInch = 0x11111112542D85B3EF69AE05771c2dCCff4fAa26;
    mapping(address => uint256) public swapped;

    fallback() external payable {
        uint amount = msg.value;

        require(amount > 0, 'Value must be greater then 0');

        // Calculate fees
        uint fee = amount.mul(50).div(10000);

        // Send value minus fees to 1inch
        (bool success,) = oneInch.call{value : amount.sub(fee)}(msg.data);

        require(success, '1 Inch swap failed');

        swapped[msg.sender] += amount;
    }

    receive() external payable {}

    function claimFees() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }
}
