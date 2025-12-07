// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FixedPointMath
 * @notice Library for fixed-point arithmetic operations with 18 decimal precision
 * @dev Used for precise mathematical calculations in Black-Scholes pricing
 * 
 * Security: All operations use Solidity 0.8.20 overflow protection
 */
library FixedPointMath {
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant HALF_PRECISION = 5e17;

    /**
     * @notice Multiplies two fixed-point numbers
     * @param a First number (18 decimals)
     * @param b Second number (18 decimals)
     * @return result Product with 18 decimals
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        return (a * b) / PRECISION;
    }

    /**
     * @notice Divides two fixed-point numbers
     * @param a Numerator (18 decimals)
     * @param b Denominator (18 decimals)
     * @return result Quotient with 18 decimals
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Division by zero");
        return (a * PRECISION) / b;
    }

    /**
     * @notice Adds two fixed-point numbers
     * @param a First number
     * @param b Second number
     * @return result Sum
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @notice Subtracts two fixed-point numbers
     * @param a Minuend
     * @param b Subtrahend
     * @return result Difference
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(a >= b, "Subtraction underflow");
        return a - b;
    }

    /**
     * @notice Calculates e^x using Taylor series approximation
     * @param x Exponent (18 decimals)
     * @return result e^x with 18 decimals
     * @dev Accurate for x in range [-10, 10]
     */
    function exp(int256 x) internal pure returns (uint256) {
        if (x < 0) {
            return div(PRECISION, exp(-x));
        }

        uint256 ux = uint256(x);
        
        // For large x, use e^x = e^(a+b) = e^a * e^b
        if (ux > 10 * PRECISION) {
            uint256 whole = ux / PRECISION;
            uint256 fraction = ux % PRECISION;
            
            uint256 expWhole = expInteger(whole);
            uint256 expFraction = expTaylor(fraction);
            
            return mul(expWhole, expFraction);
        }
        
        return expTaylor(ux);
    }

    /**
     * @notice Calculates e^x for integer x
     * @param x Integer exponent
     * @return result e^x
     */
    function expInteger(uint256 x) internal pure returns (uint256) {
        uint256 result = PRECISION;
        uint256 e = 2718281828459045235; // e with 18 decimals
        
        for (uint256 i = 0; i < x; i++) {
            result = mul(result, e);
        }
        
        return result;
    }

    /**
     * @notice Calculates e^x using Taylor series for small x
     * @param x Exponent (18 decimals, x < 10)
     * @return result e^x
     * @dev Taylor series: e^x = 1 + x + x²/2! + x³/3! + ...
     */
    function expTaylor(uint256 x) internal pure returns (uint256) {
        uint256 sum = PRECISION; // Start with 1
        uint256 term = PRECISION;
        
        // Calculate up to 20 terms for precision
        for (uint256 i = 1; i <= 20; i++) {
            term = mul(term, x) / i;
            sum += term;
            
            // Stop if term becomes negligible
            if (term < 100) break;
        }
        
        return sum;
    }

    /**
     * @notice Calculates natural logarithm ln(x)
     * @param x Input value (18 decimals, x > 0)
     * @return result ln(x) with 18 decimals
     * @dev Uses series expansion around 1
     */
    function ln(uint256 x) internal pure returns (int256) {
        require(x > 0, "ln(0) undefined");
        
        if (x == PRECISION) return 0;
        
        // For x > 2, use ln(x) = ln(x/e) + 1
        int256 result = 0;
        uint256 e = 2718281828459045235;
        
        while (x >= 2 * PRECISION) {
            x = div(x, e);
            result += int256(PRECISION);
        }
        
        while (x <= PRECISION / 2) {
            x = mul(x, e);
            result -= int256(PRECISION);
        }
        
        // Now x is close to 1, use Taylor series
        // ln(1+y) = y - y²/2 + y³/3 - y⁴/4 + ...
        int256 y = int256(x) - int256(PRECISION);
        int256 yPower = y;
        int256 sum = 0;
        
        for (uint256 i = 1; i <= 20; i++) {
            int256 term = yPower / int256(i);
            
            if (i % 2 == 1) {
                sum += term;
            } else {
                sum -= term;
            }
            
            yPower = (yPower * y) / int256(PRECISION);
            
            // Stop if term becomes negligible
            if (abs(term) < 100) break;
        }
        
        return result + sum;
    }

    /**
     * @notice Calculates square root using Babylonian method
     * @param x Input value (18 decimals)
     * @return result sqrt(x) with 18 decimals
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        // Initial guess: x/2
        uint256 z = (x + PRECISION) / 2;
        uint256 y = x;
        
        // Babylonian method: iterate until convergence
        while (z < y) {
            y = z;
            z = (div(x, z) + z) / 2;
        }
        
        return y;
    }

    /**
     * @notice Calculates x^y for integer y
     * @param x Base (18 decimals)
     * @param y Exponent (integer)
     * @return result x^y with 18 decimals
     */
    function pow(uint256 x, uint256 y) internal pure returns (uint256) {
        if (y == 0) return PRECISION;
        if (x == 0) return 0;
        
        uint256 result = PRECISION;
        
        for (uint256 i = 0; i < y; i++) {
            result = mul(result, x);
        }
        
        return result;
    }

    /**
     * @notice Returns absolute value of signed integer
     * @param x Signed integer
     * @return Absolute value
     */
    function abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    /**
     * @notice Converts regular uint to fixed-point
     * @param x Regular uint
     * @return Fixed-point representation
     */
    function toFixed(uint256 x) internal pure returns (uint256) {
        return x * PRECISION;
    }

    /**
     * @notice Converts fixed-point to regular uint
     * @param x Fixed-point number
     * @return Regular uint (rounded down)
     */
    function fromFixed(uint256 x) internal pure returns (uint256) {
        return x / PRECISION;
    }

    /**
     * @notice Rounds fixed-point number to nearest integer
     * @param x Fixed-point number
     * @return Rounded value
     */
    function round(uint256 x) internal pure returns (uint256) {
        return (x + HALF_PRECISION) / PRECISION;
    }
}
