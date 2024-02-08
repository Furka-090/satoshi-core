// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {SortedTroves} from "../../src/core/SortedTroves.sol";
import {PriceFeedAggregator} from "../../src/core/PriceFeedAggregator.sol";
import {BorrowerOperations} from "../../src/core/BorrowerOperations.sol";
import {LiquidationManager} from "../../src/core/LiquidationManager.sol";
import {StabilityPool} from "../../src/core/StabilityPool.sol";
import {TroveManager} from "../../src/core/TroveManager.sol";
import {GasPool} from "../../src/core/GasPool.sol";
import {PrismaCore} from "../../src/core/PrismaCore.sol";
import {DebtToken} from "../../src/core/DebtToken.sol";
import {Factory} from "../../src/core/Factory.sol";
import {ISortedTroves} from "../../src/interfaces/core/ISortedTroves.sol";
import {IPriceFeedAggregator} from "../../src/interfaces/core/IPriceFeedAggregator.sol";
import {IBorrowerOperations} from "../../src/interfaces/core/IBorrowerOperations.sol";
import {ILiquidationManager} from "../../src/interfaces/core/ILiquidationManager.sol";
import {IStabilityPool} from "../../src/interfaces/core/IStabilityPool.sol";
import {ITroveManager} from "../../src/interfaces/core/ITroveManager.sol";
import {IGasPool} from "../../src/interfaces/core/IGasPool.sol";
import {IPrismaCore} from "../../src/interfaces/core/IPrismaCore.sol";
import {IDebtToken} from "../../src/interfaces/core/IDebtToken.sol";
import {IFactory} from "../../src/interfaces/core/IFactory.sol";
import {
    DEPLOYER,
    OWNER,
    GUARDIAN,
    FEE_RECEIVER,
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    DEBT_TOKEN_LAYER_ZERO_END_POINT,
    GAS_COMPENSATION,
    BO_MIN_NET_DEBT
} from "../TestConfig.sol";

contract DeployBase is Test {
    /* implementation contracts addresses */
    IPriceFeedAggregator priceFeedAggregatorImpl;
    IBorrowerOperations borrowerOperationsImpl;
    ILiquidationManager liquidationManagerImpl;
    IStabilityPool stabilityPoolImpl;
    ISortedTroves sortedTrovesImpl;
    ITroveManager troveManagerImpl;
    /* non-upgradeable contracts */
    IGasPool gasPool;
    IPrismaCore prismaCore;
    IDebtToken debtToken;
    IFactory factory;
    /* UUPS proxy contracts */
    IPriceFeedAggregator priceFeedAggregatorProxy;
    IBorrowerOperations borrowerOperationsProxy;
    ILiquidationManager liquidationManagerProxy;
    IStabilityPool stabilityPoolProxy;
    /* Beacon contracts */
    IBeacon sortedTrovesBeacon;
    IBeacon troveManagerBeacon;

    /* computed contracts for deployment */
    // implementation contracts
    address cpPriceFeedAggregatorImplAddr;
    address cpBorrowerOperationsImplAddr;
    address cpLiquidationManagerImplAddr;
    address cpStabilityPoolImplAddr;
    address cpSortedTrovesImplAddr;
    address cpTroveManagerImplAddr;
    // non-upgradeable contracts
    address cpGasPoolAddr;
    address cpPrismaCoreAddr;
    address cpDebtTokenAddr;
    address cpFactoryAddr;
    // UUPS proxy contracts
    address cpPriceFeedAggregatorProxyAddr;
    address cpBorrowerOperationsProxyAddr;
    address cpLiquidationManagerProxyAddr;
    address cpStabilityPoolProxyAddr;
    // Beacon contracts
    address cpSortedTrovesBeaconAddr;
    address cpTroveManagerBeaconAddr;

    function setUp() public virtual {}

    function _deployImplementationContracts(address deployer) internal {
        vm.startPrank(deployer);

        // check if implementation contracts are not deployed
        assert(priceFeedAggregatorImpl == IPriceFeedAggregator(address(0)));
        assert(borrowerOperationsImpl == IBorrowerOperations(address(0)));
        assert(liquidationManagerImpl == ILiquidationManager(address(0)));
        assert(stabilityPoolImpl == IStabilityPool(address(0)));
        assert(sortedTrovesImpl == ISortedTroves(address(0)));
        assert(troveManagerImpl == ITroveManager(address(0)));

        priceFeedAggregatorImpl = new PriceFeedAggregator();
        borrowerOperationsImpl = new BorrowerOperations();
        liquidationManagerImpl = new LiquidationManager();
        stabilityPoolImpl = new StabilityPool();
        sortedTrovesImpl = new SortedTroves();
        troveManagerImpl = new TroveManager();

        vm.stopPrank();
    }

    function _computeContractsAddress(address deployer) internal {
        // Get nonce for computing contracts address
        uint64 nonce = vm.getNonce(deployer);

        /* computed contracts address for deployment */
        // implementation contracts
        cpSortedTrovesImplAddr = vm.computeCreateAddress(deployer, nonce);
        cpPriceFeedAggregatorImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        // non-upgradeable contracts
        cpGasPoolAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpPrismaCoreAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryAddr = vm.computeCreateAddress(deployer, ++nonce);
        // UUPS proxy contracts
        cpPriceFeedAggregatorProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        // Beacon contracts
        cpSortedTrovesBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);
    }

    function _deployNonUpgradeableContracts(address deployer) internal {
        _deployGasPool(deployer);
        _deployPrismaCore(deployer);
        _deployDebtToken(deployer);
        _deployFactory(deployer);
    }

    function _deployUUPSUpgradeableContracts(address deployer) internal {
        _deployPriceFeedAggregatorProxy(deployer);
        _deployBorrowerOperationsProxy(deployer);
        _deployLiquidationManagerProxy(deployer);
        _deployStabilityPoolProxy(deployer);
    }

    function _deployBeaconContracts(address deployer) internal {
        _deploySortedTrovesBeacon(deployer);
        _deployTroveManagerBeacon(deployer);
    }

    function _deployGasPool(address deployer) internal {
        vm.startPrank(deployer);
        assert(gasPool == IGasPool(address(0))); // check if gas pool contract is not deployed
        gasPool = new GasPool();
        vm.stopPrank();
    }

    function _deployPrismaCore(address deployer) internal {
        vm.startPrank(deployer);
        assert(gasPool != IGasPool(address(0))); // check if gas pool contract is deployed
        prismaCore = new PrismaCore(OWNER, GUARDIAN, FEE_RECEIVER);
        vm.stopPrank();
    }

    function _deployDebtToken(address deployer) internal {
        vm.startPrank(deployer);
        assert(debtToken == IDebtToken(address(0))); // check if debt token contract is not deployed
        debtToken = new DebtToken(
            DEBT_TOKEN_NAME,
            DEBT_TOKEN_SYMBOL,
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            IPrismaCore(cpPrismaCoreAddr),
            DEBT_TOKEN_LAYER_ZERO_END_POINT,
            IFactory(cpFactoryAddr),
            IGasPool(cpGasPoolAddr),
            GAS_COMPENSATION
        );
        vm.stopPrank();
    }

    function _deployFactory(address deployer) internal {
        vm.startPrank(deployer);
        assert(factory == IFactory(address(0))); // check if factory contract is not deployed
        factory = new Factory(
            IPrismaCore(cpPrismaCoreAddr),
            IDebtToken(cpDebtTokenAddr),
            IGasPool(cpGasPoolAddr),
            IPriceFeedAggregator(cpPriceFeedAggregatorProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            ILiquidationManager(cpLiquidationManagerProxyAddr),
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBeacon(cpSortedTrovesBeaconAddr),
            IBeacon(cpTroveManagerBeaconAddr),
            GAS_COMPENSATION
        );
        vm.stopPrank();
    }

    function _deployPriceFeedAggregatorProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(priceFeedAggregatorImpl != IPriceFeedAggregator(address(0))); // check if implementation contract is deployed
        assert(priceFeedAggregatorProxy == IPriceFeedAggregator(address(0))); // check if proxy contract is not deployed
        bytes memory data = abi.encodeCall(IPriceFeedAggregator.initialize, (IPrismaCore(cpPrismaCoreAddr)));
        priceFeedAggregatorProxy =
            IPriceFeedAggregator(address(new ERC1967Proxy(address(priceFeedAggregatorImpl), data)));
        vm.stopPrank();
    }

    function _deployBorrowerOperationsProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(borrowerOperationsImpl != IBorrowerOperations(address(0))); // check if implementation contract is deployed
        assert(borrowerOperationsProxy == IBorrowerOperations(address(0))); // check if proxy contract is not deployed
        bytes memory data = abi.encodeCall(
            IBorrowerOperations.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                BO_MIN_NET_DEBT,
                GAS_COMPENSATION
            )
        );
        borrowerOperationsProxy = IBorrowerOperations(address(new ERC1967Proxy(address(borrowerOperationsImpl), data)));
        vm.stopPrank();
    }

    function _deployLiquidationManagerProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(liquidationManagerImpl != ILiquidationManager(address(0))); // check if implementation contract is deployed
        assert(liquidationManagerProxy == ILiquidationManager(address(0))); // check if proxy contract is not deployed
        bytes memory data = abi.encodeCall(
            ILiquidationManager.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IStabilityPool(cpStabilityPoolProxyAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                IFactory(cpFactoryAddr),
                GAS_COMPENSATION
            )
        );
        liquidationManagerProxy = ILiquidationManager(address(new ERC1967Proxy(address(liquidationManagerImpl), data)));
        vm.stopPrank();
    }

    function _deployStabilityPoolProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(stabilityPoolImpl != IStabilityPool(address(0))); // check if implementation contract is deployed
        assert(stabilityPoolProxy == IStabilityPool(address(0))); // check if proxy contract is not deployed
        bytes memory data = abi.encodeCall(
            IStabilityPool.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr)
            )
        );
        stabilityPoolProxy = IStabilityPool(address(new ERC1967Proxy(address(stabilityPoolImpl), data)));
        vm.stopPrank();
    }

    function _deploySortedTrovesBeacon(address deployer) internal {
        vm.startPrank(deployer);
        assert(sortedTrovesImpl != ISortedTroves(address(0))); // check if implementation contract is deployed
        assert(sortedTrovesBeacon == UpgradeableBeacon(address(0))); // check if beacon contract is not deployed
        sortedTrovesBeacon = new UpgradeableBeacon(address(sortedTrovesImpl));
        vm.stopPrank();
    }

    function _deployTroveManagerBeacon(address deployer) internal {
        vm.startPrank(deployer);
        assert(troveManagerImpl != ITroveManager(address(0))); // check if implementation contract is deployed
        assert(troveManagerBeacon == UpgradeableBeacon(address(0))); // check if beacon contract is not deployed
        troveManagerBeacon = new UpgradeableBeacon(address(troveManagerImpl));
        vm.stopPrank();
    }
}
