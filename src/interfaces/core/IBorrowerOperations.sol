// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITroveManager} from "./ITroveManager.sol";
import {IPrismaCore} from "./IPrismaCore.sol";
import {IPrismaBase} from "../dependencies/IPrismaBase.sol";
import {IPrismaOwnable} from "../dependencies/IPrismaOwnable.sol";
import {IDelegatedOps} from "../dependencies/IDelegatedOps.sol";
import {IFactory} from "./IFactory.sol";
import {IDebtToken} from "./IDebtToken.sol";

enum BorrowerOperation {
    openTrove,
    closeTrove,
    adjustTrove
}

struct Balances {
    uint256[] collaterals;
    uint256[] debts;
    uint256[] prices;
}

struct TroveManagerData {
    IERC20 collateralToken;
    uint16 index;
}

interface IBorrowerOperations is IPrismaOwnable, IPrismaBase, IDelegatedOps {
    event BorrowingFeePaid(address indexed borrower, IERC20 indexed collateralToken, uint256 amount);
    event CollateralConfigured(ITroveManager troveManager, IERC20 indexed collateralToken);
    event TroveCreated(address indexed _borrower, uint256 arrayIndex);
    event TroveManagerRemoved(ITroveManager indexed troveManager);
    event TroveUpdated(address indexed _borrower, uint256 _debt, uint256 _coll, uint256 stake, uint8 operation);
    event MinNetDebtUpdated(uint256 _minNetDebt);

    function initialize(
        IPrismaCore _prismaCore,
        IDebtToken _debtToken,
        IFactory _factory,
        uint256 _minNetDebt,
        uint256 _gasCompensation
    ) external;

    function addColl(
        ITroveManager _troveManager,
        address _account,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function adjustTrove(
        ITroveManager _troveManager,
        address _account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external;

    function closeTrove(ITroveManager _troveManager, address _account) external;

    function configureCollateral(ITroveManager _troveManager, IERC20 _collateralToken) external;

    function fetchBalances() external returns (Balances memory balances);

    function getGlobalSystemBalances() external returns (uint256 totalPricedCollateral, uint256 totalDebt);

    function getTCR() external returns (uint256 globalTotalCollateralRatio);

    function openTrove(
        ITroveManager _troveManager,
        address _account,
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function removeTroveManager(ITroveManager _troveManager) external;

    function repayDebt(
        ITroveManager _troveManager,
        address _account,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function setMinNetDebt(uint256 _minNetDebt) external;

    function withdrawColl(
        ITroveManager _troveManager,
        address _account,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawDebt(
        ITroveManager _troveManager,
        address _account,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function checkRecoveryMode(uint256 TCR) external pure returns (bool);

    function debtToken() external view returns (IDebtToken);

    function factory() external view returns (IFactory);

    function getCompositeDebt(uint256 _debt) external view returns (uint256);

    function minNetDebt() external view returns (uint256);

    function troveManagersData(ITroveManager _troveManager)
        external
        view
        returns (IERC20 collateralToken, uint16 index);
}
