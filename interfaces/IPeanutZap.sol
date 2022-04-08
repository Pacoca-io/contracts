/**
                                                         __
     _____      __      ___    ___     ___     __       /\_\    ___
    /\ '__`\  /'__`\   /'___\ / __`\  /'___\ /'__`\     \/\ \  / __`\
    \ \ \_\ \/\ \_\.\_/\ \__//\ \_\ \/\ \__//\ \_\.\_  __\ \ \/\ \_\ \
     \ \ ,__/\ \__/.\_\ \____\ \____/\ \____\ \__/.\_\/\_\\ \_\ \____/
      \ \ \/  \/__/\/_/\/____/\/___/  \/____/\/__/\/_/\/_/ \/_/\/___/
       \ \_\
        \/_/

    The sweetest DeFi portfolio manager.

**/

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

interface IPeanutZap {
    function initialize(
        address _treasury,
        address _owner,
        address _wNative
    ) external;

    function zapToken(
        bytes calldata _zapInfo,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount
    ) external;

    function zapNative(
        bytes calldata _zapInfo,
        address _outputToken
    ) external payable;

    function unZapToken(
        bytes calldata _unZapInfo,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount
    ) external;

    function unZapTokenWithPermit(
        bytes calldata _unZapInfo,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount,
        bytes calldata _signatureData
    ) external;

    function unZapNative(
        bytes calldata _unZapInfo,
        address _inputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount
    ) external;

    function unZapNativeWithPermit(
        bytes calldata _unZapInfo,
        address _inputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount,
        bytes calldata _signatureData
    ) external;

    function collectDust(
        address _token
    ) external;

    function collectDustMultiple(
        address[] calldata _tokens
    ) external;

    function setTreasury(
        address _treasury
    ) external;

    receive() external payable;
}
