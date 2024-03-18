// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IOSHIToken} from "../src/interfaces/core/IOSHIToken.sol";
import {ILiquidationManager} from "../src/interfaces/core/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IPriceFeedAggregator} from "../src/interfaces/core/IPriceFeedAggregator.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {IRewardManager} from "../src/interfaces/core/IRewardManager.sol";
import {IGasPool} from "../src/interfaces/core/IGasPool.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {IPriceFeed} from "../src/interfaces/dependencies/IPriceFeed.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {IMultiTroveGetter} from "../src/helpers/interfaces/IMultiTroveGetter.sol";
import {ISatoshiBORouter} from "../src/helpers/interfaces/ISatoshiBORouter.sol";
import {IReferralManager} from "../src/helpers/interfaces/IReferralManager.sol";
import {IVestingManager} from "../src/interfaces/OSHI/IVestingManager.sol";
import {IWETH} from "../src/helpers/interfaces/IWETH.sol";
import {SortedTroves} from "../src/core/SortedTroves.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {PriceFeedAggregator} from "../src/core/PriceFeedAggregator.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {OSHIToken} from "../src/OSHI/OSHIToken.sol";
import {LiquidationManager} from "../src/core/LiquidationManager.sol";
import {StabilityPool} from "../src/core/StabilityPool.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {Factory} from "../src/core/Factory.sol";
import {CommunityIssuance} from "../src/OSHI/CommunityIssuance.sol";
import {RewardManager} from "../src/OSHI/RewardManager.sol";
import {VestingManager} from "../src/OSHI/VestingManager.sol";
import {MultiCollateralHintHelpers} from "../src/helpers/MultiCollateralHintHelpers.sol";
import {MultiTroveGetter} from "../src/helpers/MultiTroveGetter.sol";
import {SatoshiBORouter} from "../src/helpers/SatoshiBORouter.sol";
import {ReferralManager} from "../src/helpers/ReferralManager.sol";
import {
    SATOSHI_CORE_OWNER,
    SATOSHI_CORE_GUARDIAN,
    SATOSHI_CORE_FEE_RECEIVER,
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    BO_MIN_NET_DEBT,
    GAS_COMPENSATION,
    WETH_ADDRESS,
    SP_CLAIM_START_TIME,
    SP_ALLOCATION,
    REFERRAL_START_TIMESTAMP,
    REFERRAL_END_TIMESTAMP
} from "./DeploySetupConfig.sol";

contract DeploySetupScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    uint256 internal OWNER_PRIVATE_KEY;
    address public deployer;
    address public satoshiCoreOwner;
    uint64 public nonce;

    /* non-upgradeable contracts */
    IGasPool gasPool;
    ISatoshiCore satoshiCore;
    IDebtToken debtToken;
    IFactory factory;
    ICommunityIssuance communityIssuance;
    IOSHIToken oshiToken;
    IVestingManager vestingManager;
    /* implementation contracts addresses */
    ISortedTroves sortedTrovesImpl;
    IPriceFeedAggregator priceFeedAggregatorImpl;
    IBorrowerOperations borrowerOperationsImpl;
    ILiquidationManager liquidationManagerImpl;
    IStabilityPool stabilityPoolImpl;
    ITroveManager troveManagerImpl;
    IRewardManager rewardManagerImpl;
    /* UUPS proxy contracts */
    IPriceFeedAggregator priceFeedAggregatorProxy;
    IBorrowerOperations borrowerOperationsProxy;
    ILiquidationManager liquidationManagerProxy;
    IStabilityPool stabilityPoolProxy;
    IRewardManager rewardManagerProxy;
    /* Beacon contract */
    UpgradeableBeacon sortedTrovesBeacon;
    UpgradeableBeacon troveManagerBeacon;
    /* Helpers contracts */
    IMultiCollateralHintHelpers hintHelpers;
    IMultiTroveGetter multiTroveGetter;
    ISatoshiBORouter satoshiBORouter;
    IReferralManager referralManager;

    /* computed contracts for deployment */
    // implementation contracts
    address cpPriceFeedAggregatorImplAddr;
    address cpBorrowerOperationsImplAddr;
    address cpLiquidationManagerImplAddr;
    address cpStabilityPoolImplAddr;
    address cpSortedTrovesImplAddr;
    address cpTroveManagerImplAddr;
    address cpRewardManagerImplAddr;
    // non-upgradeable contracts
    address cpGasPoolAddr;
    address cpSatoshiCoreAddr;
    address cpDebtTokenAddr;
    address cpFactoryAddr;
    address cpCommunityIssuanceAddr;
    address cpOshiTokenAddr;
    address cpVestingManagerAddr;
    // UUPS proxy contracts
    address cpPriceFeedAggregatorProxyAddr;
    address cpBorrowerOperationsProxyAddr;
    address cpLiquidationManagerProxyAddr;
    address cpStabilityPoolProxyAddr;
    address cpRewardManagerProxyAddr;
    // Beacon contracts
    address cpSortedTrovesBeaconAddr;
    address cpTroveManagerBeaconAddr;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        satoshiCoreOwner = vm.addr(OWNER_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        // Get nonce for computing contracts address
        nonce = vm.getNonce(deployer);

        // computed contracts address for deployment
        // implementation contracts
        cpPriceFeedAggregatorImplAddr = vm.computeCreateAddress(deployer, nonce);
        cpBorrowerOperationsImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSortedTrovesImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpRewardManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        // non-upgradeable contracts
        cpGasPoolAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSatoshiCoreAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpCommunityIssuanceAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpOshiTokenAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpVestingManagerAddr = vm.computeCreateAddress(deployer, ++nonce);
        // upgradeable contracts
        cpPriceFeedAggregatorProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSortedTrovesBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpRewardManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        // Deploy implementation contracts
        priceFeedAggregatorImpl = new PriceFeedAggregator();
        borrowerOperationsImpl = new BorrowerOperations();
        liquidationManagerImpl = new LiquidationManager();
        stabilityPoolImpl = new StabilityPool();
        sortedTrovesImpl = new SortedTroves();
        troveManagerImpl = new TroveManager();
        rewardManagerImpl = new RewardManager();

        // Deploy non-upgradeable contracts
        // GasPool
        gasPool = new GasPool();
        assert(cpGasPoolAddr == address(gasPool));

        // SatoshiCore
        satoshiCore = new SatoshiCore(
            SATOSHI_CORE_OWNER, SATOSHI_CORE_GUARDIAN, SATOSHI_CORE_FEE_RECEIVER, cpRewardManagerProxyAddr
        );
        assert(cpSatoshiCoreAddr == address(satoshiCore));

        // DebtToken
        debtToken = new DebtToken(
            DEBT_TOKEN_NAME,
            DEBT_TOKEN_SYMBOL,
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            ISatoshiCore(cpSatoshiCoreAddr),
            IFactory(cpFactoryAddr),
            IGasPool(cpGasPoolAddr),
            GAS_COMPENSATION
        );
        assert(cpDebtTokenAddr == address(debtToken));

        // Factory
        factory = new Factory(
            ISatoshiCore(cpSatoshiCoreAddr),
            IDebtToken(cpDebtTokenAddr),
            IGasPool(cpGasPoolAddr),
            IPriceFeedAggregator(cpPriceFeedAggregatorProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            ILiquidationManager(cpLiquidationManagerProxyAddr),
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBeacon(cpSortedTrovesBeaconAddr),
            IBeacon(cpTroveManagerBeaconAddr),
            ICommunityIssuance(cpCommunityIssuanceAddr),
            IRewardManager(cpRewardManagerProxyAddr),
            GAS_COMPENSATION
        );
        assert(cpFactoryAddr == address(factory));

        // Community Issuance
        communityIssuance = new CommunityIssuance(
            ISatoshiCore(cpSatoshiCoreAddr), IOSHIToken(cpOshiTokenAddr), IStabilityPool(cpStabilityPoolProxyAddr)
        );
        assert(cpCommunityIssuanceAddr == address(communityIssuance));

        // OSHI Token
        oshiToken = new OSHIToken(cpCommunityIssuanceAddr, cpVestingManagerAddr);
        assert(cpOshiTokenAddr == address(oshiToken));

        // VestingManager
        vestingManager = new VestingManager(ISatoshiCore(cpSatoshiCoreAddr), cpOshiTokenAddr);
        assert(cpVestingManagerAddr == address(vestingManager));

        // Deploy proxy contracts
        bytes memory data;
        address proxy;

        // PriceFeedAggregator
        data = abi.encodeCall(IPriceFeedAggregator.initialize, (ISatoshiCore(cpSatoshiCoreAddr)));
        proxy = address(new ERC1967Proxy(address(priceFeedAggregatorImpl), data));
        priceFeedAggregatorProxy = IPriceFeedAggregator(proxy);
        assert(proxy == cpPriceFeedAggregatorProxyAddr);

        // BorrowerOperations
        data = abi.encodeCall(
            IBorrowerOperations.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                BO_MIN_NET_DEBT,
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(borrowerOperationsImpl), data));
        borrowerOperationsProxy = IBorrowerOperations(proxy);
        assert(proxy == cpBorrowerOperationsProxyAddr);

        // LiquidationManager
        data = abi.encodeCall(
            ILiquidationManager.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IStabilityPool(cpStabilityPoolProxyAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                IFactory(cpFactoryAddr),
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(liquidationManagerImpl), data));
        liquidationManagerProxy = ILiquidationManager(proxy);
        assert(proxy == cpLiquidationManagerProxyAddr);

        // StabilityPool
        data = abi.encodeCall(
            IStabilityPool.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr),
                ICommunityIssuance(cpCommunityIssuanceAddr)
            )
        );
        proxy = address(new ERC1967Proxy(address(stabilityPoolImpl), data));
        stabilityPoolProxy = IStabilityPool(proxy);
        assert(proxy == cpStabilityPoolProxyAddr);

        // SortedTrovesBeacon
        sortedTrovesBeacon = new UpgradeableBeacon(address(sortedTrovesImpl));
        assert(cpSortedTrovesBeaconAddr == address(sortedTrovesBeacon));

        // TroveManagerBeacon
        troveManagerBeacon = new UpgradeableBeacon(address(troveManagerImpl));
        assert(cpTroveManagerBeaconAddr == address(troveManagerBeacon));

        // rewardManager
        data = abi.encodeCall(IRewardManager.initialize, (ISatoshiCore(cpSatoshiCoreAddr)));
        proxy = address(new ERC1967Proxy(address(rewardManagerImpl), data));
        rewardManagerProxy = IRewardManager(proxy);
        assert(proxy == cpRewardManagerProxyAddr);

        // MultiCollateralHintHelpers
        hintHelpers = new MultiCollateralHintHelpers(borrowerOperationsProxy, GAS_COMPENSATION);

        // MultiTroveGetter
        multiTroveGetter = new MultiTroveGetter();

        // SatoshiBORouter
        nonce = vm.getNonce(deployer);
        address cpSatoshiBORouterAddr = vm.computeCreateAddress(deployer, nonce);
        address cpReferralManagerAddr = vm.computeCreateAddress(deployer, ++nonce);
        satoshiBORouter = new SatoshiBORouter(
            debtToken, borrowerOperationsProxy, IReferralManager(cpReferralManagerAddr), IWETH(WETH_ADDRESS)
        );
        assert(cpSatoshiBORouterAddr == address(satoshiBORouter));

        // ReferralManager
        referralManager = new ReferralManager(
            ISatoshiBORouter(cpSatoshiBORouterAddr), REFERRAL_START_TIMESTAMP, REFERRAL_END_TIMESTAMP
        );
        assert(cpReferralManagerAddr == address(referralManager));

        vm.stopBroadcast();

        // Set configuration by owner
        _setConfigByOwner(OWNER_PRIVATE_KEY);

        console.log("Deployed contracts:");
        console.log("priceFeedAggregatorImpl:", address(priceFeedAggregatorImpl));
        console.log("borrowerOperationsImpl:", address(borrowerOperationsImpl));
        console.log("liquidationManagerImpl:", address(liquidationManagerImpl));
        console.log("stabilityPoolImpl:", address(stabilityPoolImpl));
        console.log("sortedTrovesImpl:", address(sortedTrovesImpl));
        console.log("troveManagerImpl:", address(troveManagerImpl));
        console.log("rewardManagerImpl:", address(rewardManagerImpl));
        console.log("gasPool:", address(gasPool));
        console.log("satoshiCore:", address(satoshiCore));
        console.log("debtToken:", address(debtToken));
        console.log("factory:", address(factory));
        console.log("communityIssuance:", address(communityIssuance));
        console.log("oshiToken:", address(oshiToken));
        console.log("vestingManager:", address(vestingManager));
        console.log("priceFeedAggregatorProxy:", address(priceFeedAggregatorProxy));
        console.log("borrowerOperationsProxy:", address(borrowerOperationsProxy));
        console.log("liquidationManagerProxy:", address(liquidationManagerProxy));
        console.log("stabilityPoolProxy:", address(stabilityPoolProxy));
        console.log("sortedTrovesBeacon:", address(sortedTrovesBeacon));
        console.log("troveManagerBeacon:", address(troveManagerBeacon));
        console.log("rewardManagerProxy:", address(rewardManagerProxy));
        console.log("hintHelpers:", address(hintHelpers));
        console.log("multiTroveGetter:", address(multiTroveGetter));
        console.log("satoshiBORouter:", address(satoshiBORouter));
        console.log("referralManager:", address(referralManager));
    }

    function _setConfigByOwner(uint256 owner_private_key) internal {
        _setRewardManager(owner_private_key, address(rewardManagerProxy));
        _setSPCommunityIssuanceAllocation(owner_private_key);
        _setAddress(owner_private_key, borrowerOperationsProxy, IWETH(WETH_ADDRESS), debtToken, oshiToken);
        _setClaimStartTime(owner_private_key, SP_CLAIM_START_TIME);
    }

    function _setRewardManager(uint256 owner_private_key, address _rewardManager) internal {
        vm.startBroadcast(owner_private_key);
        satoshiCore.setRewardManager(_rewardManager);
        assert(satoshiCore.rewardManager() == _rewardManager);
        vm.stopBroadcast();
    }

    function _setSPCommunityIssuanceAllocation(uint256 owner_private_key) internal {
        address[] memory _recipients = new address[](1);
        _recipients[0] = cpStabilityPoolProxyAddr;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = SP_ALLOCATION;
        vm.startBroadcast(owner_private_key);
        communityIssuance.setAllocated(_recipients, _amounts);
        vm.stopBroadcast();
    }

    function _setAddress(
        uint256 owner_private_key,
        IBorrowerOperations _borrowerOperations,
        IWETH _weth,
        IDebtToken _debtToken,
        IOSHIToken _oshiToken
    ) internal {
        vm.startBroadcast(owner_private_key);
        rewardManagerProxy.setAddresses(_borrowerOperations, _weth, _debtToken, _oshiToken);
        vm.stopBroadcast();
    }

    function _setClaimStartTime(uint256 owner_private_key, uint32 _claimStartTime) internal {
        vm.startBroadcast(owner_private_key);
        stabilityPoolProxy.setClaimStartTime(_claimStartTime);
        vm.stopBroadcast();
    }
}
