// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev populated with default anvil addresses
    IERC20 constant token0 = IERC20(address(0x51AD0d703Dfe9db5909303AbbcF83f81B777E716));
    IERC20 constant token1 = IERC20(address(0x9d13F44C940146f3fDEE00768d373d24EAf9C6e5));
    IHooks constant hookContract = IHooks(address(0x3c7F608436D1ff783370A9770Cd16938136ECAc0));

    Currency constant currency0 = Currency.wrap(address(token0));
    Currency constant currency1 = Currency.wrap(address(token1));
}
