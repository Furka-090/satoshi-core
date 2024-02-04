// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IPrismaCore} from "../src/interfaces/core/IPrismaCore.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {ILiquidationManager} from "../src/interfaces/core/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IPriceFeedAggregator, OracleSetup} from "../src/interfaces/core/IPriceFeedAggregator.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {IGasPool} from "../src/interfaces/core/IGasPool.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {IPriceFeed} from "../src/interfaces/dependencies/IPriceFeed.sol";
import {SortedTroves} from "../src/core/SortedTroves.sol";
import {PrismaCore} from "../src/core/PrismaCore.sol";
import {PriceFeedAggregator} from "../src/core/PriceFeedAggregator.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {LiquidationManager} from "../src/core/LiquidationManager.sol";
import {StabilityPool} from "../src/core/StabilityPool.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {Factory} from "../src/core/Factory.sol";
import {
    PRISMA_CORE_OWNER,
    PRISMA_CORE_GUARDIAN,
    PRISMA_CORE_FEE_RECEIVER,
    NATIVE_TOKEN_FEED,
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    DEBT_TOKEN_LAYER_ZERO_END_POINT,
    BO_MIN_NET_DEBT,
    GAS_COMPENSATION
} from "./DeploySetupConfig.sol";

contract DeploySetupScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;
    uint64 public nonce;

    // implementation contracts addresses
    ISortedTroves sortedTrovesImpl;
    IPriceFeedAggregator priceFeedAggregatorImpl;
    IBorrowerOperations borrowerOperationsImpl;
    ILiquidationManager liquidationManagerImpl;
    IStabilityPool stabilityPoolImpl;
    ITroveManager troveManagerImpl;

    // non-upgradeable contracts
    IGasPool gasPool;
    IPrismaCore prismaCore;
    IDebtToken debtToken;
    IFactory factory;

    /* computed contracts for deployment */
    // non-upgradeable contracts
    address cpGasPoolAddr;
    address cpPrismaCoreAddr;
    address cpDebtTokenAddr;
    address cpFactoryAddr;
    // upgradeable contracts
    address cpSortedTrovesProxyAddr;
    address cpPriceFeedAggregatorProxyAddr;
    address cpBorrowerOperationsProxyAddr;
    address cpLiquidationManagerProxyAddr;
    address cpStabilityPoolProxyAddr;
    address cpTroveManagerProxyAddr;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        // Deploy implementation contracts
        sortedTrovesImpl = new SortedTroves();
        priceFeedAggregatorImpl = new PriceFeedAggregator();
        borrowerOperationsImpl = new BorrowerOperations();
        liquidationManagerImpl = new LiquidationManager();
        stabilityPoolImpl = new StabilityPool();
        troveManagerImpl = new TroveManager();

        // Get nonce for computing contracts address
        nonce = vm.getNonce(deployer);

        // computed contracts address for deployment
        // non-upgradeable contracts
        cpGasPoolAddr = vm.computeCreateAddress(deployer, nonce);
        cpPrismaCoreAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryAddr = vm.computeCreateAddress(deployer, ++nonce);
        // upgradeable contracts
        cpSortedTrovesProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpPriceFeedAggregatorProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);

        // Deploy non-upgradeable contracts
        // GasPool
        gasPool = new GasPool();
        assert(cpGasPoolAddr == address(gasPool));

        // PrismaCore
        prismaCore = new PrismaCore(
            PRISMA_CORE_OWNER,
            PRISMA_CORE_GUARDIAN,
            PRISMA_CORE_FEE_RECEIVER
        );
        assert(cpPrismaCoreAddr == address(prismaCore));

        // DebtToken
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
        assert(cpDebtTokenAddr == address(debtToken));

        // Factory
        factory = new Factory(
            IPrismaCore(cpPrismaCoreAddr),
            IDebtToken(cpDebtTokenAddr),
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            ISortedTroves(cpSortedTrovesProxyAddr),
            ITroveManager(cpTroveManagerProxyAddr),
            ILiquidationManager(cpLiquidationManagerProxyAddr)
        );
        assert(cpFactoryAddr == address(factory));

        // Deploy proxy contracts
        bytes memory data;
        address proxy;

        // SortedTroves
        data = abi.encodeCall(ISortedTroves.initialize, (IPrismaCore(cpPrismaCoreAddr)));
        proxy = address(new ERC1967Proxy(address(sortedTrovesImpl), data));
        assert(proxy == cpSortedTrovesProxyAddr);

        // PriceFeedAggregator
        OracleSetup[] memory oracleSetups = new OracleSetup[](0); // empty array
        data = abi.encodeCall(
            IPriceFeedAggregator.initialize,
            (IPrismaCore(cpPrismaCoreAddr), IPriceFeed(NATIVE_TOKEN_FEED), oracleSetups)
        );
        proxy = address(new ERC1967Proxy(address(priceFeedAggregatorImpl), data));
        assert(proxy == cpPriceFeedAggregatorProxyAddr);

        // BorrowerOperations
        data = abi.encodeCall(
            IBorrowerOperations.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                BO_MIN_NET_DEBT,
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(borrowerOperationsImpl), data));
        assert(proxy == cpBorrowerOperationsProxyAddr);

        // LiquidationManager
        data = abi.encodeCall(
            ILiquidationManager.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IStabilityPool(cpStabilityPoolProxyAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                IFactory(cpFactoryAddr),
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(liquidationManagerImpl), data));
        assert(proxy == cpLiquidationManagerProxyAddr);

        // StabilityPool
        data = abi.encodeCall(
            IStabilityPool.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr)
            )
        );
        proxy = address(new ERC1967Proxy(address(stabilityPoolImpl), data));
        assert(proxy == cpStabilityPoolProxyAddr);

        // TroveManager
        data = abi.encodeCall(
            ITroveManager.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IGasPool(cpGasPoolAddr),
                IDebtToken(cpDebtTokenAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr),
                IPriceFeedAggregator(cpPriceFeedAggregatorProxyAddr),
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(troveManagerImpl), data));
        assert(proxy == cpTroveManagerProxyAddr);

        vm.stopBroadcast();
    }
}
