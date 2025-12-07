// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/FixedPointMath.sol";

/**
 * @title FixedPointMathTest
 * @notice Test harness for FixedPointMath library
 */
contract FixedPointMathTest {
    using FixedPointMath for uint256;
    using FixedPointMath for int256;

    function testMul(uint256 a, uint256 b) external pure returns (uint256) {
        return a.mul(b);
    }

    function testDiv(uint256 a, uint256 b) external pure returns (uint256) {
        return a.div(b);
    }

    function testAdd(uint256 a, uint256 b) external pure returns (uint256) {
        return a.add(b);
    }

    function testSub(uint256 a, uint256 b) external pure returns (uint256) {
        return a.sub(b);
    }

    function testExp(int256 x) external pure returns (uint256) {
        return FixedPointMath.exp(x);
    }

    function testLn(uint256 x) external pure returns (int256) {
        return FixedPointMath.ln(x);
    }

    function testSqrt(uint256 x) external pure returns (uint256) {
        return FixedPointMath.sqrt(x);
    }

    function testPow(uint256 x, uint256 y) external pure returns (uint256) {
        return FixedPointMath.pow(x, y);
    }

    function testAbs(int256 x) external pure returns (uint256) {
        return FixedPointMath.abs(x);
    }

    function testToFixed(uint256 x) external pure returns (uint256) {
        return FixedPointMath.toFixed(x);
    }

    function testFromFixed(uint256 x) external pure returns (uint256) {
        return FixedPointMath.fromFixed(x);
    }

    function testRound(uint256 x) external pure returns (uint256) {
        return FixedPointMath.round(x);
    }
}
