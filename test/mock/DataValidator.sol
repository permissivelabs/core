// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;

import "../../src/interfaces/IDataValidator.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract DataValidator is IDataValidator {
    IERC721 private immutable token;

    constructor(IERC721 _token) {
        token = _token;
    }

    function isValidData(address target, bytes calldata data) external view override returns (bool result) {
        if (target != address(token)) return false;
        (address account, uint256 tokenId) = abi.decode(data, (address, uint256));
        if (token.ownerOf(tokenId) == account) return true;
    }
}
