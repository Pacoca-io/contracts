// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";

interface IBnbSwap {
    function swapped(address) external returns (uint256);
}

interface IPacocaNFTs {
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;

    function burn(address account, uint256 id, uint256 value) external;

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external;
}

interface IPacoca {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract PacocaAirdrop is ERC1155Receiver, Ownable {
    using SafeMath for uint256;

    event NewSwap(address user, uint256 amount);

    struct UserInfo {
        uint256 swapped;
        uint256 debt;
        bool migrated;
        mapping(uint256 => bool) claims;
    }

    struct NftInfo {
        bool claimable;
        uint256 value;
    }

    // ---------- CONTRACTS ----------

    address public oneInch = 0x11111112542D85B3EF69AE05771c2dCCff4fAa26;
    IBnbSwap public bnbSwap;
    IPacocaNFTs public pacocaNFTs;
    IPacoca public pacoca;

    // ---------- DATA ----------

    mapping(address => UserInfo) public users;
    mapping(uint256 => NftInfo) public nfts;
    bool public tokenClaimEnabled = false;
    bool public migrationEnabled = true;

    constructor(address _bnbSwap, address _pacocaNFTs, address _pacoca) public {
        bnbSwap = IBnbSwap(_bnbSwap);
        pacocaNFTs = IPacocaNFTs(_pacocaNFTs);
        pacoca = IPacoca(_pacoca);
    }

    // ---------- EXECUTE SWAPS ----------

    fallback() external payable {
        uint amount = msg.value;

        require(amount > 0, 'Value must be greater then 0');

        // Calculate fees
        uint fee = amount.mul(50).div(10000);

        // Send value minus fees to 1inch
        (bool success,) = oneInch.call{value : amount.sub(fee)}(msg.data);

        require(success, '1 Inch swap failed');

        _swap(msg.sender, amount);
    }

    function migrate(address _user) public {
        require(migrationEnabled, 'Migration has ended');
        require(!users[_user].migrated, 'User already migrated');

        users[_user].migrated = true;

        _swap(_user, bnbSwap.swapped(_user));
    }

    function _swap(address _user, uint256 amount) private {
        UserInfo storage user = users[msg.sender];

        user.swapped = user.swapped.add(amount);

        emit NewSwap(_user, amount);
    }

    // ---------- CLAIM REWARDS ----------

    function claimNFT(uint256 id) public {
        UserInfo storage user = users[msg.sender];
        uint256 balance = user.swapped.sub(user.debt);

        require(nfts[id].claimable, 'This NFT is not claimable yet');
        require(!user.claims[id], 'NFT already claimed');

        if (id == 0) {
            require(balance >= 20 ether, 'Not enough BNB swapped');

            user.debt = user.debt.add(20 ether);
        }
        else if (id == 1) {
            require(balance >= 10 ether, 'Not enough BNB swapped');

            user.debt = user.debt.add(10 ether);
        }
        else if (id == 2) {
            require(balance > 0, 'Not enough BNB swapped');

            user.debt = user.debt.add(5 ether);
        }

        user.claims[id] = true;
        pacocaNFTs.safeTransferFrom(address(this), msg.sender, id, 1, '');
    }

    function claimPacoca(uint nftId) public {
        require(tokenClaimEnabled, 'Tokens not yet claimable');

        pacocaNFTs.burn(msg.sender, nftId, 1);
        pacoca.transferFrom(address(this), msg.sender, nfts[nftId].value);
    }

    // ---------- ADMIN ----------

    function setNftInfo(uint id, bool claimable, uint256 value) public onlyOwner {
        NftInfo storage nft = nfts[id];

        nft.claimable = claimable;
        nft.value = value;
    }

    function setTokenClaimStatus(bool status) public onlyOwner {
        tokenClaimEnabled = status;
    }

    function setMigrationStatus(bool status) public onlyOwner {
        migrationEnabled = status;
    }

    function claimFees() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    // ---------- RECEIVE PAYMENTS ----------

    receive() external payable {}

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external override returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external override returns (bytes4) {
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }
}
