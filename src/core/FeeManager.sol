// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FeeManager - Manages and collects Permissive fee
 * @author Flydexo - @Flydex0
 * @notice Permissive core contracts that determines the percent of gas fee that is collected by Permissive and collects the fees
 */
contract FeeManager is Ownable {
    /**
     * @notice 100 basis point, 100 = 1%, 2000 = 20%
     */
    uint24 public fee = 2000;
    /**
     * @dev needs initialization because owner is set as the CREATE2 deployer in the constructor
     */
    bool initialized;

    /**
     * @notice FeePaid - Emitted when the Permissive fee is collected
     * @param from The account / module / plugin where the fee comes from
     * @param amount The amount collected in ETH
     */
    event FeePaid(address indexed from, uint256 amount);

    /**
     * @notice initialize - Initialization function to set the real owner, see CREATE2
     * @param owner The future owner of the FeeManager
     */
    function initialize(address owner) external {
        require(!initialized);
        _transferOwnership(owner);
        initialized = true;
    }

    /**
     * @notice setFee - Sets the Permissive fee, only callable by the owner
     * @param _fee The new fee (100 basis point)
     */
    function setFee(uint24 _fee) external {
        _checkOwner();
        fee = _fee;
    }

    /**
     * @notice Function called to pay the FeeManager
     * @dev used a function to avoid gas details in the core contracts
     */
    function pay() external payable {
        payable(owner()).transfer(msg.value);
        emit FeePaid(msg.sender, msg.value);
    }
}
