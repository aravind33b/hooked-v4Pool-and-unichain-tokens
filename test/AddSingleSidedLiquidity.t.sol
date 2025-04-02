// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {PositionInfo, PositionInfoLibrary} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";

import {Constants} from "../script/base/Constants.sol";
import {Config} from "../script/base/Config.sol";
import {AddSingleSidedLiquidity} from "../script/01b_AddSingleSidedLiquidity.s.sol";

contract AddSingleSidedLiquidityTest is Test, Constants, Config {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    AddSingleSidedLiquidity script;

    // Test configuration
    uint24 fee = 3000;
    int24 tickSpacing = 60;
    uint160 initSqrtPriceX96 = 79228162514264337593543950336; // 1:1 price

    function setUp() public {
        // Create script instance
        script = new AddSingleSidedLiquidity();

        // Initialize pool
        PoolKey memory pool = PoolKey({
            currency0: currency0,  // ETH (address(0))
            currency1: currency1,  // USDC from Config.sol
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        POOLMANAGER.initialize(pool, initSqrtPriceX96);
    }

    function test_AddSingleSidedLiquidity() public {
        // Get initial USDC balance
        uint256 initialBalance = IERC20(Currency.unwrap(currency1)).balanceOf(address(this));
        
        // Run the script
        script.run();

        // Get pool ID
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();

        // Get pool slot0 data
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = StateLibrary.getSlot0(POOLMANAGER, poolId);
        assertEq(sqrtPriceX96, initSqrtPriceX96, "Price should not change");

        // Verify USDC balance decreased
        uint256 finalBalance = IERC20(Currency.unwrap(currency1)).balanceOf(address(this));
        assertLt(finalBalance, initialBalance, "USDC balance should decrease");

        // Calculate expected tickUpper
        int24 expectedTickUpper = TickMath.getTickAtSqrtPrice(initSqrtPriceX96) - (TickMath.getTickAtSqrtPrice(initSqrtPriceX96) % tickSpacing);

        // Verify position exists
        uint256 tokenId = posm.nextTokenId() - 1;
        PositionInfo info = posm.positionInfo(tokenId);
        int24 tickLower = info.tickLower();
        int24 tickUpper = info.tickUpper();
        uint128 liquidity = posm.getPositionLiquidity(tokenId);
        
        assertEq(tickLower, TickMath.MIN_TICK - (TickMath.MIN_TICK % tickSpacing), "Wrong tickLower");
        assertEq(tickUpper, expectedTickUpper, "Wrong tickUpper");
        assertGt(liquidity, 0, "No liquidity added");
    }

    function test_RevertIfNoApproval() public {
        // Don't approve USDC
        vm.expectRevert();
        script.run();
    }

    function test_RevertIfInsufficientBalance() public {
        // Set USDC balance to 0
        deal(Currency.unwrap(currency1), address(this), 0);

        vm.expectRevert();
        script.run();
    }
}