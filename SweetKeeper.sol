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

interface ISweetVaultV2 {
    function earn(uint, uint) external;

    function getExpectedOutputs() external view returns (uint, uint);

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

    enum VaultType {
        LEGACY,
        SWEET,
        SWEET_V2
    }

    struct VaultInfo {
        VaultType vaultType;
        uint lastCompound;
        bool enabled;
    }

    struct CompoundInfo {
        VaultType vaultType;
        address[] vaults;
        uint[] minPlatformOutputs;
        uint[] minKeeperOutputs;
        uint[] minBurnOutputs;
        uint[] minPacocaOutputs;
    }

    mapping(VaultType => address[]) public vaults;
    mapping(address => VaultInfo) public vaultInfos;

    address public keeper;
    address public moderator;

    uint public maxDelay;
    uint public minKeeperFee;
    uint public slippageFactor;
    uint16 public maxVaults;

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

        maxDelay = 1 days;
        minKeeperFee = 10000000000000000;
        slippageFactor = 9500;
        maxVaults = 2;
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
        (upkeepNeeded, performData) = checkLegacyCompound();

        if (upkeepNeeded) {
            return (upkeepNeeded, performData);
        }

        (upkeepNeeded, performData) = checkSweetCompound();

        if (upkeepNeeded) {
            return (upkeepNeeded, performData);
        }

        (upkeepNeeded, performData) = checkSweetV2Compound();

        if (upkeepNeeded) {
            return (upkeepNeeded, performData);
        }

        return (false, "");
    }

    function checkCompound(
        address _vault
    ) public view returns (
        bool compoundNeeded,
        uint platformOutput,
        uint keeperOutput,
        uint burnOutput,
        uint pacocaOutput
    ) {
        compoundNeeded = false;
        platformOutput = 0;
        keeperOutput = 0;
        burnOutput = 0;
        pacocaOutput = 0;

        VaultInfo memory vaultInfo = vaultInfos[_vault];

        if (!vaultInfo.enabled)
            return (compoundNeeded, platformOutput, keeperOutput, burnOutput, pacocaOutput);

        if (vaultInfo.vaultType == VaultType.SWEET || vaultInfo.vaultType == VaultType.SWEET_V2)
            if (ISweetVault(_vault).totalStake() == 0)
                return (compoundNeeded, platformOutput, keeperOutput, burnOutput, pacocaOutput);

        compoundNeeded = block.timestamp >= vaultInfo.lastCompound + maxDelay;

        if (vaultInfo.vaultType == VaultType.LEGACY)
            return (compoundNeeded, platformOutput, keeperOutput, burnOutput, pacocaOutput);

        if (vaultInfo.vaultType == VaultType.SWEET) {
            (platformOutput, keeperOutput, burnOutput, pacocaOutput) = _getExpectedOutputs(
                VaultType.SWEET,
                _vault
            );

            if (keeperOutput >= minKeeperFee)
                compoundNeeded = true;

            return (compoundNeeded, platformOutput, keeperOutput, burnOutput, pacocaOutput);
        }

        if (vaultInfo.vaultType == VaultType.SWEET_V2) {
            (platformOutput, , , pacocaOutput) = _getExpectedOutputs(
                VaultType.SWEET_V2,
                _vault
            );

            keeperOutput = platformOutput.div(11);

            if (keeperOutput >= minKeeperFee)
                compoundNeeded = true;

            return (compoundNeeded, platformOutput, keeperOutput, burnOutput, pacocaOutput);
        }
    }

    function checkLegacyCompound() public view returns (
        bool upkeepNeeded,
        bytes memory performData
    ) {
        uint totalLength = legacyVaultsLength();
        uint actualLength = 0;

        CompoundInfo memory tempCompoundInfo = CompoundInfo(
            VaultType.LEGACY,
            new address[](totalLength),
            new uint[](0),
            new uint[](0),
            new uint[](0),
            new uint[](0)
        );

        for (uint16 index = 0; index < totalLength; ++index) {
            if (maxVaults == actualLength) {
                continue;
            }

            address vault = vaults[VaultType.LEGACY][index];

            (bool compoundNeeded, , , ,) = checkCompound(vault);

            if (compoundNeeded) {
                tempCompoundInfo.vaults[actualLength] = vault;

                actualLength = actualLength + 1;
            }
        }

        if (actualLength > 0) {
            address[] memory vaultsToCompound = new address[](actualLength);

            for (uint16 index = 0; index < actualLength; ++index) {
                vaultsToCompound[index] = tempCompoundInfo.vaults[index];
            }

            return (true, abi.encode(
                VaultType.LEGACY,
                vaultsToCompound,
                new uint[](0),
                new uint[](0),
                new uint[](0),
                new uint[](0)
            ));
        }

        return (false, "");
    }

    function checkSweetCompound() public view returns (
        bool upkeepNeeded,
        bytes memory performData
    ) {
        uint totalLength = sweetVaultsLength();
        uint actualLength = 0;

        CompoundInfo memory tempCompoundInfo = CompoundInfo(
            VaultType.SWEET,
            new address[](totalLength),
            new uint[](totalLength),
            new uint[](totalLength),
            new uint[](totalLength),
            new uint[](totalLength)
        );

        for (uint16 index = 0; index < totalLength; ++index) {
            if (maxVaults == actualLength) {
                continue;
            }

            address vault = vaults[VaultType.SWEET][index];

            (bool compoundNeeded, uint platformOutput, uint keeperOutput, uint burnOutput, uint pacocaOutput) = checkCompound(vault);

            if (compoundNeeded) {
                tempCompoundInfo.vaults[actualLength] = vault;
                tempCompoundInfo.minPlatformOutputs[actualLength] = platformOutput.mul(slippageFactor).div(10000);
                tempCompoundInfo.minKeeperOutputs[actualLength] = keeperOutput.mul(slippageFactor).div(10000);
                tempCompoundInfo.minBurnOutputs[actualLength] = burnOutput.mul(slippageFactor).div(10000);
                tempCompoundInfo.minPacocaOutputs[actualLength] = pacocaOutput.mul(slippageFactor).div(10000);

                actualLength = actualLength + 1;
            }
        }

        if (actualLength > 0) {
            CompoundInfo memory compoundInfo = CompoundInfo(
                VaultType.SWEET,
                new address[](actualLength),
                new uint[](actualLength),
                new uint[](actualLength),
                new uint[](actualLength),
                new uint[](actualLength)
            );

            for (uint16 index = 0; index < actualLength; ++index) {
                compoundInfo.vaults[index] = tempCompoundInfo.vaults[index];
                compoundInfo.minPlatformOutputs[index] = tempCompoundInfo.minPlatformOutputs[index];
                compoundInfo.minKeeperOutputs[index] = tempCompoundInfo.minKeeperOutputs[index];
                compoundInfo.minBurnOutputs[index] = tempCompoundInfo.minBurnOutputs[index];
                compoundInfo.minPacocaOutputs[index] = tempCompoundInfo.minPacocaOutputs[index];
            }

            return (true, abi.encode(
                compoundInfo.vaultType,
                compoundInfo.vaults,
                compoundInfo.minPlatformOutputs,
                compoundInfo.minKeeperOutputs,
                compoundInfo.minBurnOutputs,
                compoundInfo.minPacocaOutputs
            ));
        }

        return (false, "");
    }

    function checkSweetV2Compound() public view returns (
        bool upkeepNeeded,
        bytes memory performData
    ) {
        uint totalLength = sweetVaultsV2Length();
        uint actualLength = 0;

        CompoundInfo memory tempCompoundInfo = CompoundInfo(
            VaultType.SWEET_V2,
            new address[](totalLength),
            new uint[](totalLength),
            new uint[](0),
            new uint[](0),
            new uint[](totalLength)
        );

        for (uint16 index = 0; index < totalLength; ++index) {
            if (maxVaults == actualLength) {
                continue;
            }

            address vault = vaults[VaultType.SWEET_V2][index];

            (bool compoundNeeded, uint platformOutput, , , uint pacocaOutput) = checkCompound(vault);

            if (compoundNeeded) {
                tempCompoundInfo.vaults[actualLength] = vault;
                tempCompoundInfo.minPlatformOutputs[actualLength] = platformOutput.mul(slippageFactor).div(10000);
                tempCompoundInfo.minPacocaOutputs[actualLength] = pacocaOutput.mul(slippageFactor).div(10000);

                actualLength = actualLength + 1;
            }
        }

        if (actualLength > 0) {
            address[] memory vaultsToCompound = new address[](actualLength);
            uint[] memory minPlatformOutputs = new uint[](actualLength);
            uint[] memory minPacocaOutputs = new uint[](actualLength);

            for (uint16 index = 0; index < actualLength; ++index) {
                vaultsToCompound[index] = tempCompoundInfo.vaults[index];
                minPlatformOutputs[index] = tempCompoundInfo.minPlatformOutputs[index];
                minPacocaOutputs[index] = tempCompoundInfo.minPacocaOutputs[index];
            }

            return (true, abi.encode(
                VaultType.SWEET_V2,
                vaultsToCompound,
                minPlatformOutputs,
                new uint[](0),
                new uint[](0),
                minPacocaOutputs
            ));
        }

        return (false, "");
    }

    function performUpkeep(
        bytes calldata performData
    ) external override onlyKeeper {
        (
        VaultType _type,
        address[] memory _vaults,
        uint[] memory _minPlatformOutputs,
        uint[] memory _minKeeperOutputs,
        uint[] memory _minBurnOutputs,
        uint[] memory _minPacocaOutputs
        ) = abi.decode(
            performData,
            (VaultType, address[], uint[], uint[], uint[], uint[])
        );

        _earn(
            _type,
            _vaults,
            _minPlatformOutputs,
            _minKeeperOutputs,
            _minBurnOutputs,
            _minPacocaOutputs
        );
    }

    function compound(address _vault) public {
        VaultInfo memory vaultInfo = vaultInfos[_vault];
        uint timestamp = block.timestamp;

        require(
            vaultInfo.lastCompound < timestamp - 12 hours,
            "SweetKeeper::compound: Too soon"
        );

        if (vaultInfo.vaultType == VaultType.LEGACY) {
            return _compoundLegacyVault(_vault, timestamp);
        }

        if (vaultInfo.vaultType == VaultType.SWEET) {
            return _compoundSweetVault(_vault, 0, 0, 0, 0, timestamp);
        }

        if (vaultInfo.vaultType == VaultType.SWEET_V2) {
            return _compoundSweetVaultV2(_vault, 0, 0, timestamp);
        }
    }

    function _compoundLegacyVault(address _vault, uint timestamp) private {
        ILegacyVault(_vault).earn();

        vaultInfos[_vault].lastCompound = timestamp;

        emit Compound(_vault, timestamp);
    }

    function _compoundSweetVault(
        address _vault,
        uint _minPlatformOutput,
        uint _minKeeperOutput,
        uint _minBurnOutput,
        uint _minPacocaOutput,
        uint timestamp
    ) private {
        ISweetVault(_vault).earn(
            _minPlatformOutput,
            _minKeeperOutput,
            _minBurnOutput,
            _minPacocaOutput
        );

        vaultInfos[_vault].lastCompound = timestamp;

        emit Compound(_vault, timestamp);
    }

    function _compoundSweetVaultV2(
        address _vault,
        uint _minPlatformOutput,
        uint _minPacocaOutput,
        uint timestamp
    ) private {
        ISweetVaultV2(_vault).earn(
            _minPlatformOutput,
            _minPacocaOutput
        );

        vaultInfos[_vault].lastCompound = timestamp;

        emit Compound(_vault, timestamp);
    }

    function _earn(
        VaultType _type,
        address[] memory _vaults,
        uint[] memory _minPlatformOutputs,
        uint[] memory _minKeeperOutputs,
        uint[] memory _minBurnOutputs,
        uint[] memory _minPacocaOutputs
    ) private {
        uint timestamp = block.timestamp;
        uint length = _vaults.length;

        if (_type == VaultType.LEGACY) {
            for (uint index = 0; index < length; ++index) {
                _compoundLegacyVault(
                    _vaults[index],
                    timestamp
                );
            }

            return;
        }

        if (_type == VaultType.SWEET) {
            for (uint index = 0; index < length; ++index) {
                _compoundSweetVault(
                    _vaults[index],
                    _minPlatformOutputs[index],
                    _minKeeperOutputs[index],
                    _minBurnOutputs[index],
                    _minPacocaOutputs[index],
                    timestamp
                );
            }

            return;
        }

        if (_type == VaultType.SWEET_V2) {
            for (uint index = 0; index < length; ++index) {
                _compoundSweetVaultV2(
                    _vaults[index],
                    _minPlatformOutputs[index],
                    _minPacocaOutputs[index],
                    timestamp
                );
            }
        }
    }

    function _getExpectedOutputs(
        VaultType _type,
        address _vault
    ) private view returns (
        uint, uint, uint, uint
    ) {
        if (_type == VaultType.SWEET) {
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
        }
        else if (_type == VaultType.SWEET_V2) {
            try ISweetVaultV2(_vault).getExpectedOutputs() returns (
                uint platformOutput,
                uint pacocaOutput
            ) {
                return (platformOutput, 0, 0, pacocaOutput);
            }
            catch (bytes memory) {
            }
        }

        return (0, 0, 0, 0);
    }

    function legacyVaultsLength() public view returns (uint) {
        return vaults[VaultType.LEGACY].length;
    }

    function sweetVaultsLength() public view returns (uint) {
        return vaults[VaultType.SWEET].length;
    }

    function sweetVaultsV2Length() public view returns (uint) {
        return vaults[VaultType.SWEET_V2].length;
    }

    function addVault(VaultType _type, address _vault) public onlyModerator {
        require(
            vaultInfos[_vault].lastCompound == 0,
            "SweetKeeper::addVault: Vault already exists"
        );

        vaultInfos[_vault] = VaultInfo(
            _type,
            block.timestamp,
            true
        );

        vaults[_type].push(_vault);
    }

    function addVaults(
        VaultType _type,
        address[] memory _vaults
    ) public onlyModerator {
        for (uint index = 0; index < _vaults.length; ++index) {
            addVault(_type, _vaults[index]);
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
