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

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface ILegacyVault {
    function earn() external;
}

interface ISweetVault {
    function earn(uint, uint, uint, uint) external;

    function getExpectedOutputs() external view returns (
        uint platformOutput,
        uint keeperOutput,
        uint burnOutput,
        uint pacocaOutput
    );
}

interface KeeperCompatibleInterface {
    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (
        bool upkeepNeeded,
        bytes memory performData
    );

    function performUpkeep(
        bytes calldata performData
    ) external;
}

contract SweetKeeper is Ownable, KeeperCompatibleInterface {
    using SafeMath for uint;

    struct CompoundInfo {
        address[] legacyVaults;
        address[] sweetVaults;
        uint[] minPlatformOutputs;
        uint[] minKeeperOutputs;
        uint[] minBurnOutputs;
        uint[] minPacocaOutputs;
    }

    mapping(address => uint) public lastCompounds;

    address public keeper;

    uint public maxDelay = 1 days;
    uint public minKeeperFee = 5500000000000000;
    uint public slippageFactor = 9600; // 4%

    constructor(
        address _keeper,
        address _owner
    ) public {
        keeper = _keeper;

        transferOwnership(_owner);
    }

    modifier onlyKeeper() {
        require(msg.sender == keeper, "SweetKeeper::onlyKeeper: Not keeper");
        _;
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external override view returns (
        bool upkeepNeeded,
        bytes memory performData
    ) {
        (address[] memory legacyVaults, address[] memory sweetVaults) = abi.decode(
            checkData,
            (address[], address[])
        );

        CompoundInfo memory tempCompoundInfo = CompoundInfo(
            new address[](legacyVaults.length),
            new address[](sweetVaults.length),
            new uint[](sweetVaults.length),
            new uint[](sweetVaults.length),
            new uint[](sweetVaults.length),
            new uint[](sweetVaults.length)
        );

        uint legacyVaultsLength = 0;
        uint sweetVaultsLength = 0;

        for (uint index = 0; index < sweetVaults.length; ++index) {
            address vault = sweetVaults[index];

            (uint platformOutput, uint keeperOutput, uint burnOutput, uint pacocaOutput) = _getExpectedOutputs(vault);

            if (
                block.timestamp >= lastCompounds[vault] + maxDelay
                || keeperOutput >= minKeeperFee
            ) {
                tempCompoundInfo.sweetVaults[sweetVaultsLength] = vault;

                tempCompoundInfo.minPlatformOutputs[sweetVaultsLength] = platformOutput.mul(slippageFactor).div(10000);
                tempCompoundInfo.minKeeperOutputs[sweetVaultsLength] = keeperOutput.mul(slippageFactor).div(10000);
                tempCompoundInfo.minBurnOutputs[sweetVaultsLength] = burnOutput.mul(slippageFactor).div(10000);
                tempCompoundInfo.minPacocaOutputs[sweetVaultsLength] = pacocaOutput.mul(slippageFactor).div(10000);

                sweetVaultsLength = sweetVaultsLength + 1;
            }
        }

        for (uint index = 0; index < legacyVaults.length; ++index) {
            address vault = legacyVaults[index];

            if (block.timestamp >= lastCompounds[vault] + maxDelay) {
                tempCompoundInfo.legacyVaults[legacyVaultsLength] = vault;

                legacyVaultsLength = legacyVaultsLength + 1;
            }
        }

        if (legacyVaultsLength > 0 || sweetVaultsLength > 0) {
            CompoundInfo memory compoundInfo = CompoundInfo(
                new address[](legacyVaultsLength),
                new address[](sweetVaultsLength),
                new uint[](sweetVaultsLength),
                new uint[](sweetVaultsLength),
                new uint[](sweetVaultsLength),
                new uint[](sweetVaultsLength)
            );

            for (uint index = 0; index < legacyVaultsLength; ++index) {
                compoundInfo.legacyVaults[index] = tempCompoundInfo.legacyVaults[index];
            }

            for (uint index = 0; index < sweetVaultsLength; ++index) {
                compoundInfo.sweetVaults[index] = tempCompoundInfo.sweetVaults[index];
                compoundInfo.minPlatformOutputs[index] = tempCompoundInfo.minPlatformOutputs[index];
                compoundInfo.minKeeperOutputs[index] = tempCompoundInfo.minKeeperOutputs[index];
                compoundInfo.minBurnOutputs[index] = tempCompoundInfo.minBurnOutputs[index];
                compoundInfo.minPacocaOutputs[index] = tempCompoundInfo.minPacocaOutputs[index];
            }

            return (true, abi.encode(
                compoundInfo.legacyVaults,
                compoundInfo.sweetVaults,
                compoundInfo.minPlatformOutputs,
                compoundInfo.minKeeperOutputs,
                compoundInfo.minBurnOutputs,
                compoundInfo.minPacocaOutputs
            ));
        }

        return (false, "");
    }

    function performUpkeep(
        bytes calldata performData
    ) external override onlyKeeper {
        (
        address[] memory legacyVaults,
        address[] memory sweetVaults,
        uint[] memory minPlatformOutputs,
        uint[] memory minKeeperOutputs,
        uint[] memory minBurnOutputs,
        uint[] memory minPacocaOutputs
        ) = abi.decode(
            performData,
            (address[], address[], uint[], uint[], uint[], uint[])
        );

        _earn(
            legacyVaults,
            sweetVaults,
            minPlatformOutputs,
            minKeeperOutputs,
            minBurnOutputs,
            minPacocaOutputs
        );
    }

    function _earn(
        address[] memory _legacyVaults,
        address[] memory _sweetVaults,
        uint[] memory _minPlatformOutputs,
        uint[] memory _minKeeperOutputs,
        uint[] memory _minBurnOutputs,
        uint[] memory _minPacocaOutputs
    ) private {
        uint legacyLength = _legacyVaults.length;

        for (uint index = 0; index < legacyLength; ++index) {
            address vault = _legacyVaults[index];

            ILegacyVault(vault).earn();

            lastCompounds[vault] = block.timestamp;
        }

        uint sweetLength = _sweetVaults.length;

        for (uint index = 0; index < sweetLength; ++index) {
            address vault = _sweetVaults[index];

            ISweetVault(vault).earn(
                _minPlatformOutputs[index],
                _minKeeperOutputs[index],
                _minBurnOutputs[index],
                _minPacocaOutputs[index]
            );

            lastCompounds[vault] = block.timestamp;
        }
    }

    function _getExpectedOutputs(
        address _vault
    ) private view returns (
        uint, uint, uint, uint
    ) {
        try ISweetVault(_vault).getExpectedOutputs() returns (
            uint platformOutput,
            uint keeperOutput,
            uint burnOutput,
            uint pacocaOutput
        ) {
            return (platformOutput, keeperOutput, burnOutput, pacocaOutput);
        }
        catch (bytes memory) {
        }

        return (0, 0, 0, 0);
    }

    function setKeeper(address _keeper) public onlyOwner {
        keeper = _keeper;
    }

    function setMaxDelay(uint _maxDelay) public onlyOwner {
        maxDelay = _maxDelay;
    }

    function setMinKeeperFee(uint _minKeeperFee) public onlyOwner {
        minKeeperFee = _minKeeperFee;
    }

    function setSlippageFactor(uint _slippageFactor) public onlyOwner {
        slippageFactor = _slippageFactor;
    }
}
