// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Burnable.sol";

contract PacocaCollectibles is ERC1155("https://api.pacoca.io/nfts/"), ERC1155Burnable, Ownable {
    function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        _mint(account, id, amount, data);
    }

    function getCollectibleURI(uint256 id) external view returns (string memory) {
        if (bytes(this.uri(id)).length == 0) {
            return "";
        }
        else {
            // abi.encodePacked is being used to concatenate strings
            return string(abi.encodePacked(this.uri(id), uint2str(id), ".json"));
        }
    }

    function uint2str(uint _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }

        uint j = _i;
        uint len;

        while (j != 0) {
            len++;
            j /= 10;
        }

        bytes memory bStr = new bytes(len);
        uint k = len;

        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bStr[k] = b1;
            _i /= 10;
        }

        return string(bStr);
    }
}
