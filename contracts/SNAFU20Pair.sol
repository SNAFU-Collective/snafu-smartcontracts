// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

// ERC1155
import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155MetadataURI.sol";

import "./ERC20.sol";


contract SNAFU20Pair is ERC20, ERC1155Receiver {
    address public owner;
    address public daoAddress;
    address public nftAddress;
    uint256 public max_token_value_cap;
    uint256 public fee;
    bool public enableSwap;

    mapping(uint256 => uint256) public tokenIdsToEditions;

    //using EnumerableSet for EnumerableSet.UintSet;
    //EnumerableSet.UintSet lockedNfts;

    event Withdraw(uint256[] indexed _tokenIds, uint256[] indexed amounts);
    event SetEditions(uint256[] indexed _tokenIds, uint256[] indexed editions);

    // create new token
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _nftAddress,
        address _daoAddress,
        uint256 _fee,
        uint256 _max_token_value_cap
    ) public {
        _mint(msg.sender, _initialSupply);
        owner = msg.sender;
        fee = _fee;
        name = _name;
        symbol = _symbol;
        decimals = 18;
        nftAddress = _nftAddress;
        daoAddress = _daoAddress;
        max_token_value_cap = _max_token_value_cap;
    }

    function getTokenValue(uint256 tokenId) public view returns (uint256) {
        return max_token_value_cap.div(tokenIdsToEditions[tokenId]);
    }

    function getTokenInfo(uint256 tokenId, uint256 value)
        public
        view
        returns (
            string memory,
            uint256,
            uint256,
            uint256 //URI,  editions, sellprice, fee
        )
    {
        uint256 tokenPrice = getTokenValue(tokenId);
        uint256 computedFee = (tokenPrice.mul(value)).mul(fee).div(100);
        uint256 price =
            (tokenPrice.mul(value)).mul(uint256(100).sub(fee)).div(100);

        return (
            IERC1155MetadataURI(nftAddress).uri(tokenId),
            tokenIdsToEditions[tokenId],
            price,
            computedFee
        );
    }

    // withdraw nft and burn tokens
    function withdraw(
        uint256[] calldata _tokenIds,
        uint256[] calldata amounts,
        address receipient
    ) external {
        if (_tokenIds.length == 1) {
            require(tokenIdsToEditions[_tokenIds[0]] != 0, "editions not set");
            _burn(msg.sender, (getTokenValue(_tokenIds[0]).mul(amounts[0])));
            _withdraw1155(address(this), receipient, _tokenIds[0], amounts[0]);
        } else {
            _batchWithdraw1155(address(this), receipient, _tokenIds, amounts);
        }

        emit Withdraw(_tokenIds, amounts);
    }

    function _withdraw1155(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 value
    ) internal {
        IERC1155(nftAddress).safeTransferFrom(
            _from,
            _to,
            _tokenId,
            value,
            "0x0"
        );
    }

    function _batchWithdraw1155(
        address _from,
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory amounts
    ) internal {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(tokenIdsToEditions[_tokenIds[i]] != 0, "editions not set");
            _burn(msg.sender, (getTokenValue(_tokenIds[i]).mul(amounts[i])));
        }

        IERC1155(nftAddress).safeBatchTransferFrom(
            _from,
            _to,
            _tokenIds,
            amounts,
            "0x0"
        );
    }

    function swap1155(
        uint256 in_id,
        uint256 in_amount,
        uint256 out_id,
        uint256 out_amount
    ) external {
        require(
            tokenIdsToEditions[in_id] != 0 && tokenIdsToEditions[out_id] != 0,
            "Editions must be set!"
        );
        require(enableSwap, "Swap is disabled");
        require(in_amount == out_amount, "Need to swap same amount of NFTs");
        require(
            getTokenValue(in_id) == getTokenValue(out_id),
            "Token to swap must have the same value"
        );

        IERC1155(nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            out_id,
            out_amount,
            "0x0"
        );
        IERC1155(nftAddress).safeTransferFrom(
            msg.sender,
            address(this),
            in_id,
            in_amount,
            "INTERNAL"
        );
    }

    function onERC1155Received(
        address operator,
        address,
        uint256 tokenId,
        uint256 value,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(nftAddress == msg.sender, "forbidden");
        require(tokenIdsToEditions[tokenId] != 0, "editions not set");
        if (keccak256(data) != keccak256("INTERNAL")) {
            uint256 tokenPrice = getTokenValue(tokenId);
            _mint(daoAddress, (tokenPrice.mul(value)).mul(fee).div(100));
            _mint(
                operator,
                (tokenPrice.mul(value)).mul(uint256(100).sub(fee)).div(100)
            );
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(nftAddress == msg.sender, "forbidden");
        if (keccak256(data) != keccak256("INTERNAL")) {
            for (uint256 i = 0; i < ids.length; i++) {
                require(tokenIdsToEditions[ids[i]] != 0, "editions not set");
                uint256 tokenPrice = getTokenValue(ids[i]);

                _mint(
                    daoAddress,
                    (tokenPrice.mul(values[i])).mul(fee).div(100)
                );
                _mint(
                    operator,
                    (tokenPrice.mul(values[i])).mul(uint256(100).sub(fee)).div(
                        100
                    )
                );
            }
        }
        return this.onERC1155BatchReceived.selector;
    }

    function setParams(
        string calldata _name,
        string calldata _symbol
    ) public {
        require(msg.sender == owner, "!authorized");
        name = _name;
        symbol = _symbol;
    }

    function setEnableSwap(bool _enableSwap) public{
        require(msg.sender == owner, "!authorized");
        enableSwap = _enableSwap;
    }

    function setFee(uint256 _fee) public{
        require(msg.sender == owner, "!authorized");
        fee = _fee;
    }

    function setOwner(address _owner) public{
        require(msg.sender == owner, "!authorized");
        require(owner != address(0), "cannot set contract owner to zero");
        owner = _owner;
    }

    function setDaoAddress(address _daoAddress) public{
        require(msg.sender == owner, "!authorized");
        require(_daoAddress != address(0), "cannot set contract owner to zero");
        daoAddress = _daoAddress;
    }

    function setTokenValueCap(uint256 _max_token_value_cap) public{
        require(msg.sender == owner, "!authorized");
        require(_max_token_value_cap != 0, "Max value cannot be zero");
        max_token_value_cap = _max_token_value_cap;
    }

    function setTokenEditions(
        uint256[] memory tokenIds,
        uint256[] memory editions
    ) external {
        require(msg.sender == owner, "!authorized");
        require(
            tokenIds.length == editions.length,
            "Array must have same size!"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(editions[i] != 0, "Cannot set an edition number to zero");
            tokenIdsToEditions[tokenIds[i]] = editions[i];
        }

        emit SetEditions(tokenIds, editions);
    }
}
