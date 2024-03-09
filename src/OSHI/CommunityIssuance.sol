// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOSHIToken} from "../interfaces/core/IOSHIToken.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {ICommunityIssuance} from "../interfaces/core/ICommunityIssuance.sol";
import {IStabilityPool} from "../interfaces/core/IStabilityPool.sol";

contract CommunityIssuance is ICommunityIssuance, SatoshiOwnable {
    IStabilityPool public stabilityPool;
    IOSHIToken public OSHIToken;

    mapping(address => uint256) public allocated; // allocate to troveManagers and SP

    constructor(ISatoshiCore _satoshiCore) {
        __SatoshiOwnable_init(_satoshiCore);
    }

    function setAllocated(address[] calldata _recipients, uint256[] calldata _amounts) external onlyOwner {
        require(_recipients.length == _amounts.length, "Community Issuance: Arrays must be of equal length");
        for (uint256 i; i < _recipients.length; ++i) {
            allocated[_recipients[i]] = _amounts[i];
            emit SetAllocation(_recipients[i], _amounts[i]);
        }
    }

    function setAddresses(IOSHIToken _oshiToken, IStabilityPool _stabilityPool) external onlyOwner {
        OSHIToken = _oshiToken;
        stabilityPool = _stabilityPool;

        emit OSHITokenSet(_oshiToken);
        emit StabilityPoolSet(_stabilityPool);
    }

    function transferAllocatedTokens(address receiver, uint256 amount) external {
        if (amount > 0) {
            require(allocated[msg.sender] >= amount, "Community Issuance: Insufficient balance");
            allocated[msg.sender] -= amount;
            OSHIToken.transfer(receiver, amount);
        }
    }
}
