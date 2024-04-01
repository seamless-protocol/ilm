// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ILMFactoryStorage as Storage } from "../storage/ILMFactoryStorage.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";

import {
    CollateralRatio,
    StrategyAssets
} from "../types/DataTypes.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { ISwapper } from "../interfaces/ISwapper.sol";
import { IILMFactory } from "../interfaces/IILMFactory.sol";
import { ILoopStrategy } from "../interfaces/ILoopStrategy.sol";

contract LoopStrategyFactory is AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // TODO: make storage lib
    IILMFactory ilmFactory;
    IPoolAddressesProvider poolAddressesProvider;
    IPriceOracleGetter oracle;
    ISwapper swapper;
    uint256 loopStrategyIlmId;

    function LoopStrategyFactory_init(
        address _initialAdmin,
        IILMFactory _ilmFactory,
        IPoolAddressesProvider _poolAddressesProvider,
        IPriceOracleGetter _oracle,
        ISwapper _swapper,
        uint256 _loopStrategyIlmId
    ) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        ilmFactory = _ilmFactory;
        poolAddressesProvider = _poolAddressesProvider;
        oracle = _oracle;
        swapper = _swapper;
        loopStrategyIlmId = _loopStrategyIlmId;

        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
    }

    function deployNewLoopStrategy(
        string memory _erc20name,
        string memory _erc20symbol,
        address _initialAdmin,
        StrategyAssets memory _strategyAssets,
        CollateralRatio memory _collateralRatioTargets,
        uint256 _ratioMargin,
        uint16 _maxIterations
    ) external onlyRole(MANAGER_ROLE) {
        ilmFactory.deployNewBeaconProxy(
            loopStrategyIlmId,
            abi.encodeWithSelector(
                ILoopStrategy.LoopStrategy_init.selector,
                _erc20name,
                _erc20symbol,
                _initialAdmin,
                _strategyAssets,
                _collateralRatioTargets,
                poolAddressesProvider,
                oracle,
                swapper,
                _ratioMargin,
                _maxIterations
            )
        );
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    { }

    // TODO setters/getters

    // function setPoolAddressesProvider(IPoolAddressesProvider poolAddressesProvider) external onlyRole(MANAGER_ROLE) { }

    // function getPoolAddressesProvider() external view returns (IPoolAddressesProvider poolAddressesProvider) { }

    // function setSwapper(ISwapper swapper) external onlyRole(MANAGER_ROLE) { }

    // function getSwapper() external view returns (ISwapper swapper) { }
}
