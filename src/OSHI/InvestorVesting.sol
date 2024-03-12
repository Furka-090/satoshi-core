// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Investor Vesting Contract
 *        Rule: Release 10% at M4, 6 month cliff, 24 month linear vesting
 */

contract InvestorVesting is Ownable {
    using SafeERC20 for IERC20;
    
    event TokenReleased(address indexed, uint256);
    event TokenVested(address, uint256, uint64);

    uint256 private _erc20Released;
    uint256 private _tokenReleasedM4;
    uint256 private _tokenVestingAmount;
    uint64 private immutable _start;
    uint64 private constant _duration = 30 days * 24;
    uint64 private constant _FOUR_MONTHS = 30 days * 4;
    uint64 private constant _SIX_MONTHS = 30 days * 6;
    uint256 private constant _TEN_PERCENT = 10;
    IERC20 public immutable token;  // OSHI token
    
    /**
     * @dev Sets the sender as the satoshi owner, the beneficiary as the pending owner, the start timestamp and the
     * vesting duration of the vesting wallet.
     */
    constructor(address _token, uint256 _amount, address _beneficiary, uint64 startTimestamp) Ownable() {
        require(_beneficiary != address(0), "TeamVesting: beneficiary is the zero address");
        _start = startTimestamp;
        token = IERC20(_token);
        _tokenReleasedM4 = _amount / _TEN_PERCENT; // release 10% at M4
        _tokenVestingAmount = _amount - _tokenReleasedM4;
        _transferOwnership(_beneficiary);

        // transfer OSHI token to this contract
        token.safeTransferFrom(msg.sender, address(this), _amount);
        emit TokenVested(_beneficiary, _amount, _start);
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Getter for the end timestamp.
     */
    function end() public view virtual returns (uint256) {
        return start() + _SIX_MONTHS + duration();
    }

    /**
     * @dev Amount of token already released
     */
    function released() public view virtual returns (uint256) {
        return _erc20Released;
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {TokenReleased} event.
     */
    function releaseAfterM6() public virtual {
        uint256 amount = releasable();
        _erc20Released += amount;
        _tokenVestingAmount -= amount;
        emit TokenReleased(address(token), amount);
        token.safeTransfer(owner(), amount);
    }

    function releaseAtM4() public {
        require(block.timestamp >= start() + _FOUR_MONTHS, "InvestorVesting: Month 4 not reached");
        require(_tokenReleasedM4 > 0, "InvestorVesting: No tokens to release");
        _tokenReleasedM4 = 0;

        // Add the logic to transfer the tokens from the contract to the investor
        token.safeTransfer(owner(), _tokenReleasedM4);
        emit TokenReleased(address(token), _tokenReleasedM4);
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(_tokenVestingAmount + released(), timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= end()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - (start() + _SIX_MONTHS))) / duration();
        }
    }

}