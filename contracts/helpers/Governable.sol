// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

abstract contract Governable {
    address public govAddress;

    event SetGov(address _govAddress);

    modifier onlyAllowGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    function setGov(address _govAddress) public virtual onlyAllowGov {
        govAddress = _govAddress;
        emit SetGov(_govAddress);
    }
}
