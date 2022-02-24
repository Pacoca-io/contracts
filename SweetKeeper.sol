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

    // @Deprecated CompoundInfo
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

    mapping(address => bool) public keepers;
    address public moderator;

    uint public maxDelay;
    uint public minKeeperFee;
    uint public slippageFactor;

    // @Deprecated maxVaults
    uint16 public maxVaults;
    // @Deprecated keeper
    address public keeper;

    event Compound(address indexed vault, uint timestamp);

    function initialize(
        address _moderator,
        address _owner
    ) public initializer {
        moderator = _moderator;

        __Ownable_init();
        transferOwnership(_owner);

        maxDelay = 1 days;
        minKeeperFee = 10000000000000000;
        slippageFactor = 9500;
        maxVaults = 2;
    }

    modifier onlyKeeper() {
        require(keepers[msg.sender], "SweetKeeper::onlyKeeper: Not keeper");
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

        for (uint16 index = 0; index < totalLength; ++index) {
            address vault = vaults[VaultType.LEGACY][index];

            (bool compoundNeeded, , , ,) = checkCompound(vault);

            if (compoundNeeded) {
                uint zero = uint(0);

                return (true, abi.encode(
                    VaultType.LEGACY,
                    vault,
                    zero,
                    zero,
                    zero,
                    zero
                ));
            }
        }

        return (false, "");
    }

    function checkSweetCompound() public view returns (
        bool upkeepNeeded,
        bytes memory performData
    ) {
        uint totalLength = sweetVaultsLength();

        for (uint16 index = 0; index < totalLength; ++index) {
            address vault = vaults[VaultType.SWEET][index];

            (bool compoundNeeded, uint platformOutput, uint keeperOutput, uint burnOutput, uint pacocaOutput) = checkCompound(vault);

            if (compoundNeeded) {
                return (true, abi.encode(
                    VaultType.SWEET,
                    vault,
                    platformOutput.mul(slippageFactor).div(10000),
                    keeperOutput.mul(slippageFactor).div(10000),
                    burnOutput.mul(slippageFactor).div(10000),
                    pacocaOutput.mul(slippageFactor).div(10000)
                ));
            }
        }

        return (false, "");
    }

    function checkSweetV2Compound() public view returns (
        bool upkeepNeeded,
        bytes memory performData
    ) {
        uint totalLength = sweetVaultsV2Length();

        for (uint16 index = 0; index < totalLength; ++index) {
            address vault = vaults[VaultType.SWEET_V2][index];

            (bool compoundNeeded, uint platformOutput, , , uint pacocaOutput) = checkCompound(vault);

            if (compoundNeeded) {
                uint zero = uint(0);

                return (true, abi.encode(
                    VaultType.SWEET_V2,
                    vault,
                    platformOutput.mul(slippageFactor).div(10000),
                    zero,
                    zero,
                    pacocaOutput.mul(slippageFactor).div(10000)
                ));
            }
        }

        return (false, "");
    }

    function performUpkeep(
        bytes calldata performData
    ) external override onlyKeeper {
        (
        VaultType _type,
        address _vault,
        uint _minPlatformOutput,
        uint _minKeeperOutput,
        uint _minBurnOutput,
        uint _minPacocaOutput
        ) = abi.decode(
            performData,
            (VaultType, address, uint, uint, uint, uint)
        );

        _earn(
            _type,
            _vault,
            _minPlatformOutput,
            _minKeeperOutput,
            _minBurnOutput,
            _minPacocaOutput
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
        address _vault,
        uint _minPlatformOutput,
        uint _minKeeperOutput,
        uint _minBurnOutput,
        uint _minPacocaOutput
    ) private {
        uint timestamp = block.timestamp;

        if (_type == VaultType.LEGACY) {
            _compoundLegacyVault(
                _vault,
                timestamp
            );

            return;
        }

        if (_type == VaultType.SWEET) {
            _compoundSweetVault(
                _vault,
                _minPlatformOutput,
                _minKeeperOutput,
                _minBurnOutput,
                _minPacocaOutput,
                timestamp
            );

            return;
        }

        if (_type == VaultType.SWEET_V2) {
            _compoundSweetVaultV2(
                _vault,
                _minPlatformOutput,
                _minPacocaOutput,
                timestamp
            );
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

    function compoundInfo(
        address _vault
    ) external view returns (
        uint lastCompound,
        uint keeperFee
    ) {
        VaultInfo memory vaultInfo = vaultInfos[_vault];
        bool isSweet = vaultInfo.vaultType == VaultType.SWEET;
        bool isSweetV2 = vaultInfo.vaultType == VaultType.SWEET_V2;

        lastCompound = vaultInfo.lastCompound;
        keeperFee = 0;

        if ((isSweet || isSweetV2) && ISweetVault(_vault).totalStake() == 0) {
            return (lastCompound, keeperFee);
        }

        if (isSweet) {
            (, keeperFee,,) = _getExpectedOutputs(
                VaultType.SWEET,
                _vault
            );
        }
        else if (isSweetV2) {
            (uint platformOutput,,,) = _getExpectedOutputs(
                VaultType.SWEET_V2,
                _vault
            );

            keeperFee = platformOutput.div(11);
        }
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

    function enableKeeper(address _keeper) public onlyOwner {
        keepers[_keeper] = true;
    }

    function disableKeeper(address _keeper) public onlyOwner {
        keepers[_keeper] = false;
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
}
