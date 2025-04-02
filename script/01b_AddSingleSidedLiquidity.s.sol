// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {EasyPosm} from "../test/utils/EasyPosm.sol";
import {Constants} from "./base/Constants.sol";
import {Config} from "./base/Config.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract AddSingleSidedLiquidity is Script, Constants, Config {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using EasyPosm for IPositionManager;

    uint24 public constant LP_FEE = 3000;
    int24 public constant TICK_SPACING = 60;
    uint256 public constant token1Amount = 1e6; // 1 USDC (6 decimals)

    function run() external {
        PoolKey memory pool = PoolKey({
            currency0: currency0,  // ETH
            currency1: currency1,  // USDC
            fee: LP_FEE,
            tickSpacing: TICK_SPACING,
            hooks: hookContract
        });

        // Get current pool sqrtPrice and tick
        (uint160 sqrtPriceX96,,,) = POOLMANAGER.getSlot0(pool.toId());
        int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        // Use [currentTick - 1200, currentTick) to avoid deep MIN_TICK edge cases
        int24 tickUpper = currentTick - (TICK_SPACING * 10);
        int24 tickLower = tickUpper - (TICK_SPACING * 20);

        console.log("currentTick:", currentTick);
        console.log("tickLower:", tickLower);
        console.log("tickUpper:", tickUpper);

        // Calculate liquidity from token1 (USDC)
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            token1Amount
        );
        console.log("liquidity:", liquidity);

        uint256 requiredToken1 = LiquidityAmounts.getAmount1ForLiquidity(
        TickMath.getSqrtPriceAtTick(tickLower),
        TickMath.getSqrtPriceAtTick(tickUpper),
        liquidity
        );
        console.log("requiredToken1:", requiredToken1);

        uint256 amount1Max = requiredToken1 + 1_000; // 0.001 USDC buffer
        uint256 amount0Max = 0;
        bytes memory hookData = new bytes(0);

        vm.startBroadcast();
        tokenApprovals();
        vm.stopBroadcast();

        vm.startBroadcast();
        IPositionManager(address(posm)).mint(
            pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, msg.sender, block.timestamp + 60, hookData
        );
        vm.stopBroadcast();
    }

    function tokenApprovals() public {
        if (!currency1.isAddressZero()) {
            IERC20(Currency.unwrap(currency1)).approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(Currency.unwrap(currency1), address(posm), type(uint160).max, type(uint48).max);
        }
    }
}
