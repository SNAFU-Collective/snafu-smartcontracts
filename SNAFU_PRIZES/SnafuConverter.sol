// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

contract SnafuConverter is ERC721URIStorage, IERC1155Receiver{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    address public nftAddress;
    mapping(uint256 => uint256) public tokenIdsMap;


    constructor(address _nftAddress) ERC721("SnafuConverter", "SnafuPrize") {
        nftAddress = _nftAddress;
    }


    function onERC1155Received(
        address operator,
        address fromAddress,
        uint256 tokenId,
        uint256 value,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(nftAddress == msg.sender, "forbidden");
        for(uint256 i = 0; i < value; i++){
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            _mint(fromAddress, newItemId);
            _setTokenURI(newItemId, IERC1155MetadataURI(nftAddress).uri(tokenId));
            tokenIdsMap[newItemId] = tokenId;
        }

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address fromAddress,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(nftAddress == msg.sender, "forbidden");
            for (uint256 i = 0; i < ids.length; i++) {
                string memory tokenURI = IERC1155MetadataURI(nftAddress).uri(ids[i]);
                for(uint256 j = 0; j < values[i]; j++){
                    _tokenIds.increment();
                    uint256 newItemId = _tokenIds.current();
                    _mint(fromAddress, newItemId);
                    _setTokenURI(newItemId, tokenURI);
                    tokenIdsMap[newItemId] = ids[i];
                }
            }
        return this.onERC1155BatchReceived.selector;
    }
    
    function claim(uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721Burnable: caller is not owner nor approved");
        IERC1155(nftAddress).safeTransferFrom(address(this), msg.sender, tokenIdsMap[tokenId], 1, "");
        _burn(tokenId);
    }
    
}