// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MockERC20} from "./mocks/MockER20.s.sol";

contract CreateToken is Script {
    MockERC20 public token0;
    MockERC20 public token1;

    function run() external {
        vm.startBroadcast();
        
        // Deploy tokens
        MockERC20 tokenA = new MockERC20("MockA", "A", 18);
        MockERC20 tokenB = new MockERC20("MockB", "B", 18);
        
        if (uint160(address(tokenA)) < uint160(address(tokenB))) {
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }
        
        console.log("Token0 is:", address(token0));
        console.log("Token1 is:", address(token1));

        // Mint tokens to the deployer
        uint256 mintAmount = 1000 * 1e18; 
        token0.mint(msg.sender, mintAmount);
        token1.mint(msg.sender, mintAmount);
        console.log("Minted", mintAmount, "tokens to", msg.sender);
        
        vm.stopBroadcast();
    }
}