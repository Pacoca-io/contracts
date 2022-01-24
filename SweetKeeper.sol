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

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface ILegacyVault {
    function earn() external;
}

interface ISweetVault {
    function earn(uint, uint, uint, uint) external;

    function getExpectedOutputs() external view returns (uint, uint, uint, uint);

    function totalStake() external view returns (uint);
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

contract SweetKeeper is OwnableUpgradeable, KeeperCompatibleInterface {
    using SafeMath for uint;

    struct VaultInfo {
        uint lastCompound;
        bool enabled;
    }

    struct CompoundInfo {
        address[] legacyVaults;
        address[] sweetVaults;
        uint[] minPlatformOutputs;
        uint[] minKeeperOutputs;
        uint[] minBurnOutputs;
        uint[] minPacocaOutputs;
    }

    address[] public legacyVaults;
    address[] public sweetVaults;

    mapping(address => VaultInfo) public vaultInfos;

    address public keeper;
    address public moderator;

    uint public maxDelay = 1 days;
    uint public minKeeperFee = 5500000000000000;
    uint public slippageFactor = 9500; // 5%
    uint16 public maxVaults = 3;

    event Compound(address indexed vault, uint timestamp);

    function initialize(
        address _keeper,
        address _moderator,
        address _owner
    ) public initializer {
        keeper = _keeper;
        moderator = _moderator;

        __Ownable_init();
        transferOwnership(_owner);
    }

    modifier onlyKeeper() {
        require(msg.sender == keeper, "SweetKeeper::onlyKeeper: Not keeper");
        _;
    }

    modifier onlyModerator() {
        require(msg.sender == moderator, "SweetKeeper::onlyModerator: Not moderator");
        _;
    }

    function checkUpkeep(
        bytes calldata
    ) external override view returns (
        bool upkeepNeeded,
        bytes memory performData
    ) {
        CompoundInfo memory tempCompoundInfo = CompoundInfo(
            new address[](legacyVaults.length),
            new address[](sweetVaults.length),
            new uint[](sweetVaults.length),
            new uint[](sweetVaults.length),
            new uint[](sweetVaults.length),
            new uint[](sweetVaults.length)
        );

        uint16 legacyVaultsLength = 0;
        uint16 sweetVaultsLength = 0;

        for (uint16 index = 0; index < sweetVaults.length; ++index) {
            if (maxVaults == sweetVaultsLength) {
                continue;
            }

            address vault = sweetVaults[index];
            VaultInfo memory vaultInfo = vaultInfos[vault];

            if (!vaultInfo.enabled || ISweetVault(vault).totalStake() == 0) {
                continue;
            }

            (uint platformOutput, uint keeperOutput, uint burnOutput, uint pacocaOutput) = _getExpectedOutputs(vault);

            if (
                block.timestamp >= vaultInfo.lastCompound + maxDelay
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

        for (uint16 index = 0; index < legacyVaults.length; ++index) {
            if (maxVaults == (sweetVaultsLength + legacyVaultsLength)) {
                continue;
            }

            address vault = legacyVaults[index];
            VaultInfo memory vaultInfo = vaultInfos[vault];

            if (!vaultInfo.enabled) {
                continue;
            }

            if (block.timestamp >= vaultInfo.lastCompound + maxDelay) {
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

            for (uint16 index = 0; index < legacyVaultsLength; ++index) {
                compoundInfo.legacyVaults[index] = tempCompoundInfo.legacyVaults[index];
            }

            for (uint16 index = 0; index < sweetVaultsLength; ++index) {
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
        address[] memory _legacyVaults,
        address[] memory _sweetVaults,
        uint[] memory _minPlatformOutputs,
        uint[] memory _minKeeperOutputs,
        uint[] memory _minBurnOutputs,
        uint[] memory _minPacocaOutputs
        ) = abi.decode(
            performData,
            (address[], address[], uint[], uint[], uint[], uint[])
        );

        _earn(
            _legacyVaults,
            _sweetVaults,
            _minPlatformOutputs,
            _minKeeperOutputs,
            _minBurnOutputs,
            _minPacocaOutputs
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
        uint timestamp = block.timestamp;

        for (uint index = 0; index < legacyLength; ++index) {
            address vault = _legacyVaults[index];

            ILegacyVault(vault).earn();

            vaultInfos[vault].lastCompound = timestamp;

            emit Compound(vault, timestamp);
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

            vaultInfos[vault].lastCompound = timestamp;

            emit Compound(vault, timestamp);
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

    function legacyVaultsLength() external view returns (uint) {
        return legacyVaults.length;
    }

    function sweetVaultsLength() external view returns (uint) {
        return sweetVaults.length;
    }

    function addVault(address _vault, bool _legacy) public onlyModerator {
        require(
            vaultInfos[_vault].lastCompound == 0,
            "SweetKeeper::addVault: Vault already exists"
        );

        vaultInfos[_vault] = VaultInfo(
            block.timestamp,
            true
        );

        if (_legacy) {
            legacyVaults.push(_vault);
        }
        else {
            sweetVaults.push(_vault);
        }
    }

    function enableVault(address _vault) external onlyModerator {
        vaultInfos[_vault].enabled = true;
    }

    function disableVault(address _vault) external onlyModerator {
        vaultInfos[_vault].enabled = false;
    }

    function setKeeper(address _keeper) public onlyOwner {
        keeper = _keeper;
    }

    function setModerator(address _moderator) public onlyOwner {
        moderator = _moderator;
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

    function setMaxVaults(uint16 _maxVaults) public onlyOwner {
        maxVaults = _maxVaults;
    }
}
