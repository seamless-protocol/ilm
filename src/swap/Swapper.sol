// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ConversionMath } from "../libraries/math/ConversionMath.sol";
import { ISwapper } from "../interfaces/ISwapper.sol";
import { USDWadRayMath } from "../libraries/math/USDWadRayMath.sol";
import { SwapperStorage as Storage } from "../storage/SwapperStorage.sol";
import { Step } from "../types/DataTypes.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Swapper
/// @notice Routing contract for swaps across different DEXs
contract Swapper is ISwapper, AccessControlUpgradeable, UUPSUpgradeable {
    using USDWadRayMath for uint256;

    /// @dev role which can use the swap function, only given to ILM strategies
    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    /// @dev role which can change routes and offset factor
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    /// @dev role which can upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    constructor() {
        _disableInitializers();
    }

    /// @dev initializer function for Swapper contract
    function Swapper_init(
        address initialAdmin,
        IPriceOracleGetter oracle,
        uint256 offsetDeviationUSD
    ) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);

        Storage.Layout storage $ = Storage.layout();
        $.oracle = oracle;
        $.offsetDeviationUSD = offsetDeviationUSD;
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    { }

    /// @inheritdoc ISwapper
    function setRoute(IERC20 from, IERC20 to, Step[] calldata steps)
        external
        onlyRole(MANAGER_ROLE)
    {
        Storage.Layout storage $ = Storage.layout();

        // remove route if it exists
        if ($.route[from][to].length != 0) {
            _removeRoute(from, to);
        }

        for (uint256 i; i < steps.length; ++i) {
            if (address(steps[i].adapter) == address(0)) {
                revert InvalidAddress();
            }

            $.route[from][to].push(steps[i]);
        }

        emit RouteSet(from, to, steps);
    }

    /// @inheritdoc ISwapper
    function removeRoute(IERC20 from, IERC20 to)
        external
        onlyRole(MANAGER_ROLE)
    {
        _removeRoute(from, to);
    }

    /// @inheritdoc ISwapper
    function setOffsetFactor(IERC20 from, IERC20 to, uint256 offsetUSD)
        external
        onlyRole(MANAGER_ROLE)
    {
        if (offsetUSD == 0 || offsetUSD > USDWadRayMath.USD) {
            revert USDValueOutsideRange();
        }

        Storage.layout().offsetUSD[from][to] = offsetUSD;

        emit OffsetFactorSet(from, to, offsetUSD);
    }

    /// @inheritdoc ISwapper
    function setOracle(IPriceOracleGetter oracle)
        external
        onlyRole(MANAGER_ROLE)
    {
        Storage.layout().oracle = oracle;

        emit OracleSet(oracle);
    }

    /// @inheritdoc ISwapper
    function setOffsetDeviationUSD(uint256 offsetDeviationUSD)
        external
        onlyRole(MANAGER_ROLE)
    {
        if (offsetDeviationUSD > USDWadRayMath.USD) {
            revert USDValueOutsideRange();
        }

        Storage.layout().offsetDeviationUSD = offsetDeviationUSD;

        emit OffsetDeviationSet(offsetDeviationUSD);
    }

    /// @inheritdoc ISwapper
    function swap(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary
    ) external onlyRole(STRATEGY_ROLE) returns (uint256 toAmount) {
        Step[] memory steps = Storage.layout().route[from][to];

        uint256 initialAmount = fromAmount;

        from.transferFrom(msg.sender, address(this), fromAmount);

        // execute the swap for each swap-step in the route,
        // updating `fromAmount` to be the amount received from
        // each step
        for (uint256 i; i < steps.length; ++i) {
            steps[i].from.approve(address(steps[i].adapter), fromAmount);

            // should handle address(0) cases ie for ETH?
            fromAmount = steps[i].adapter.executeSwap(
                steps[i].from, steps[i].to, fromAmount, payable(address(this))
            );
        }

        // set the received amount as the amount received from the final
        // step of the route
        toAmount = fromAmount;

        _enforceSlippageLimit(from, to, initialAmount, toAmount);

        to.transfer(beneficiary, toAmount);
    }

    /// @inheritdoc ISwapper
    function getOffsetDeviationUSD()
        external
        view
        returns (uint256 offsetDeviationUSD)
    {
        return Storage.layout().offsetDeviationUSD;
    }

    /// @inheritdoc ISwapper
    function getOracle() external view returns (IPriceOracleGetter oracle) {
        return Storage.layout().oracle;
    }

    /// @inheritdoc ISwapper
    function getRoute(IERC20 from, IERC20 to)
        external
        view
        returns (Step[] memory steps)
    {
        return Storage.layout().route[from][to];
    }

    /// @inheritdoc ISwapper
    function offsetFactor(IERC20 from, IERC20 to)
        external
        view
        returns (uint256 offsetUSD)
    {
        return Storage.layout().offsetUSD[from][to];
    }

    /// @notice deletes an existing route
    /// @param from address of token route ends with
    /// @param to address of token route starts with
    function _removeRoute(IERC20 from, IERC20 to) internal {
        delete Storage.layout().route[from][to];

        emit RouteRemoved(from, to);
    }

    /// @notice enforces the maximum slippage allowed for a given swap
    /// @param from address of starting token
    /// @param to address of ending token
    /// @param fromAmount amount being swapped
    /// @param toAmount amount received
    function _enforceSlippageLimit(
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        uint256 toAmount
    ) internal view {
        Storage.Layout storage $ = Storage.layout();
        IPriceOracleGetter oracle = $.oracle;

        // convert to/from amount to dollars
        uint256 fromAmountUSD = ConversionMath.convertAssetToUSD(
            fromAmount,
            oracle.getAssetPrice(address(from)),
            IERC20Metadata(address(from)).decimals()
        );
        uint256 toAmountUSD = ConversionMath.convertAssetToUSD(
            toAmount,
            oracle.getAssetPrice(address(to)),
            IERC20Metadata(address(to)).decimals()
        );

        uint256 offsetUSD = $.offsetUSD[from][to];
        uint256 maxDeviationUSD =
            offsetUSD.usdMul($.offsetDeviationUSD).usdDiv(USDWadRayMath.USD);

        // ensure these amounts do not differ by more than given slippage
        uint256 maxSlippageUSD = fromAmountUSD.usdMul(
            offsetUSD + maxDeviationUSD
        ).usdDiv(USDWadRayMath.USD);
        
        // for the very low amounts allow 1 wei of slippage
        if (maxSlippageUSD == 0) {
            maxSlippageUSD = 1;
        }

        // for the very low amounts allow 1 wei of slippage
        if (maxSlippageUSD == 0) {
            maxSlippageUSD = 1;
        }

        if (fromAmountUSD - maxSlippageUSD > toAmountUSD) {
            revert MaxSlippageExceeded();
        }
    }
}