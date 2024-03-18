// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
import {IOSHIToken} from "./IOSHIToken.sol";
import {IStabilityPool} from "./IStabilityPool.sol";

interface ICommunityIssuance is ISatoshiOwnable {
    event SetAllocation(address indexed receiver, uint256 amount);
    event OSHITokenSet(IOSHIToken _oshiToken);
    event StabilityPoolSet(IStabilityPool _stabilityPool);

    function transferAllocatedTokens(address receiver, uint256 amount) external;
    function setAllocated(address[] calldata _recipients, uint256[] calldata _amounts) external;
}
