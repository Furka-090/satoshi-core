// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IFactory} from "../interfaces/IFactory.sol";

struct Collateral {
    address collateral;
    address[] troveManagers;
}

/*  Helper contract for grabbing Trove data for the front end. Not part of the core Prisma system. */
contract TroveManagerGetters {
    IFactory public immutable factory;

    constructor(IFactory _factory) {
        factory = _factory;
    }

    /**
     * @notice Returns all active system trove managers and collaterals, as an
     *     `       array of tuples of [(collateral, [troveManager, ...]), ...]
     */
    function getAllCollateralsAndTroveManagers() external view returns (Collateral[] memory) {
        uint256 length = factory.troveManagerCount();
        address[2][] memory troveManagersAndCollaterals = new address[2][](length);
        address[] memory uniqueCollaterals = new address[](length);
        uint256 collateralCount;
        for (uint256 i = 0; i < length; i++) {
            ITroveManager troveManager = factory.troveManagers(i);
            IERC20 collateral = troveManager.collateralToken();
            troveManagersAndCollaterals[i] = [address(troveManager), address(collateral)];
            for (uint256 x = 0; x < length; x++) {
                if (uniqueCollaterals[x] == address(collateral)) break;
                if (uniqueCollaterals[x] == address(0)) {
                    uniqueCollaterals[x] = address(collateral);
                    collateralCount++;
                    break;
                }
            }
        }
        Collateral[] memory collateralMap = new Collateral[](collateralCount);
        for (uint256 i = 0; i < collateralCount; i++) {
            collateralMap[i].collateral = uniqueCollaterals[i];
            uint256 tmCollCount = 0;
            address[] memory troveManagers = new address[](length);
            for (uint256 x = 0; x < length; x++) {
                if (troveManagersAndCollaterals[x][1] == uniqueCollaterals[i]) {
                    troveManagers[tmCollCount] = troveManagersAndCollaterals[x][0];
                    tmCollCount++;
                }
            }
            collateralMap[i].troveManagers = new address[](tmCollCount);
            for (uint256 x = 0; x < tmCollCount; x++) {
                collateralMap[i].troveManagers[x] = troveManagers[x];
            }
        }

        return collateralMap;
    }

    /**
     * @notice Returns a list of trove managers where `account` has an existing trove
     */
    function getActiveTroveManagersForAccount(address account) external view returns (ITroveManager[] memory) {
        uint256 length = factory.troveManagerCount();
        ITroveManager[] memory troveManagers = new ITroveManager[](length);
        uint256 tmCount;
        for (uint256 i = 0; i < length; i++) {
            ITroveManager troveManager = factory.troveManagers(i);
            if (troveManager.getTroveStatus(account) > 0) {
                troveManagers[tmCount] = troveManager;
                tmCount++;
            }
        }
        assembly {
            mstore(troveManagers, tmCount)
        }
        return troveManagers;
    }
}
