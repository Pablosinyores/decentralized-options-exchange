// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/FixedPointMath.sol";

/**
 * @title BlackScholes
 * @notice On-chain Black-Scholes option pricing model for European options
 * @dev Implements the classic Black-Scholes formula with fixed-point arithmetic
 * 
 * Security Features:
 * - Pure functions (no state changes)
 * - Overflow protection via Solidity 0.8.20
 * - Input validation for all parameters
 * - Precision handling with 18 decimals
 * 
 * Formula:
 * Call: C = S₀N(d₁) - Ke^(-rT)N(d₂)
 * Put:  P = Ke^(-rT)N(-d₂) - S₀N(-d₁)
 * 
 * Where:
 * d₁ = [ln(S₀/K) + (r + σ²/2)T] / (σ√T)
 * d₂ = d₁ - σ√T
 */
library BlackScholes {
    using FixedPointMath for uint256;
    using FixedPointMath for int256;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant SQRT_2PI = 2506628274631000502; // √(2π) with 18 decimals

    enum OptionType { CALL, PUT }

    struct OptionParams {
        uint256 spotPrice;      // Current price of underlying (18 decimals)
        uint256 strikePrice;    // Strike price (18 decimals)
        uint256 timeToExpiry;   // Time to expiry in seconds
        uint256 volatility;     // Implied volatility (18 decimals, e.g., 0.5 = 50%)
        uint256 riskFreeRate;   // Risk-free rate (18 decimals, e.g., 0.05 = 5%)
    }

    /**
     * @notice Calculates option price using Black-Scholes model
     * @param params Option parameters
     * @param optionType CALL or PUT
     * @return price Option premium (18 decimals)
     */
    function calculatePrice(
        OptionParams memory params,
        OptionType optionType
    ) internal pure returns (uint256 price) {
        // Validate inputs
        require(params.spotPrice > 0, "Invalid spot price");
        require(params.strikePrice > 0, "Invalid strike price");
        require(params.timeToExpiry > 0, "Invalid time to expiry");
        require(params.volatility > 0, "Invalid volatility");
        
        // Calculate d1 and d2
        (int256 d1, int256 d2) = calculateD1D2(params);
        
        // Calculate N(d1) and N(d2)
        uint256 Nd1 = cumulativeNormalDistribution(d1);
        uint256 Nd2 = cumulativeNormalDistribution(d2);
        
        // Calculate discount factor: e^(-rT)
        int256 exponent = -int256(params.riskFreeRate.mul(params.timeToExpiry) / 365 days);
        uint256 discountFactor = FixedPointMath.exp(exponent);
        
        if (optionType == OptionType.CALL) {
            // C = S₀N(d₁) - Ke^(-rT)N(d₂)
            uint256 term1 = params.spotPrice.mul(Nd1);
            uint256 term2 = params.strikePrice.mul(discountFactor).mul(Nd2);
            
            price = term1 > term2 ? term1 - term2 : 0;
        } else {
            // P = Ke^(-rT)N(-d₂) - S₀N(-d₁)
            uint256 NminusD1 = PRECISION - Nd1;
            uint256 NminusD2 = PRECISION - Nd2;
            
            uint256 term1 = params.strikePrice.mul(discountFactor).mul(NminusD2);
            uint256 term2 = params.spotPrice.mul(NminusD1);
            
            price = term1 > term2 ? term1 - term2 : 0;
        }
    }

    /**
     * @notice Calculates d1 and d2 parameters for Black-Scholes
     * @param params Option parameters
     * @return d1 First parameter (18 decimals)
     * @return d2 Second parameter (18 decimals)
     * 
     * @dev d₁ = [ln(S₀/K) + (r + σ²/2)T] / (σ√T)
     *      d₂ = d₁ - σ√T
     */
    function calculateD1D2(
        OptionParams memory params
    ) internal pure returns (int256 d1, int256 d2) {
        // Calculate time in years (18 decimals)
        uint256 timeInYears = (params.timeToExpiry * PRECISION) / 365 days;
        
        // Calculate ln(S/K)
        uint256 ratio = params.spotPrice.div(params.strikePrice);
        int256 lnRatio = FixedPointMath.ln(ratio);
        
        // Calculate σ²/2
        uint256 volSquared = params.volatility.mul(params.volatility);
        uint256 halfVolSquared = volSquared / 2;
        
        // Calculate (r + σ²/2)T
        uint256 drift = (params.riskFreeRate + halfVolSquared).mul(timeInYears);
        
        // Calculate σ√T
        uint256 sqrtTime = FixedPointMath.sqrt(timeInYears);
        uint256 volSqrtTime = params.volatility.mul(sqrtTime);
        
        require(volSqrtTime > 0, "Invalid vol*sqrt(T)");
        
        // Calculate d1 = [ln(S/K) + (r + σ²/2)T] / (σ√T)
        int256 numerator = lnRatio + int256(drift);
        d1 = numerator * int256(PRECISION) / int256(volSqrtTime);
        
        // Calculate d2 = d1 - σ√T
        d2 = d1 - int256(volSqrtTime);
    }

    /**
     * @notice Calculates cumulative normal distribution N(x)
     * @param x Input value (18 decimals)
     * @return result N(x) with 18 decimals
     * @dev Uses Abramowitz and Stegun approximation (error < 7.5e-8)
     */
    function cumulativeNormalDistribution(int256 x) internal pure returns (uint256) {
        // For x < -10, N(x) ≈ 0
        if (x < -10 * int256(PRECISION)) return 0;
        
        // For x > 10, N(x) ≈ 1
        if (x > 10 * int256(PRECISION)) return PRECISION;
        
        // For negative x, use symmetry: N(-x) = 1 - N(x)
        if (x < 0) {
            return PRECISION - cumulativeNormalDistribution(-x);
        }
        
        uint256 ux = uint256(x);
        
        // Abramowitz and Stegun approximation
        // N(x) = 1 - φ(x)(b₁t + b₂t² + b₃t³ + b₄t⁴ + b₅t⁵)
        // where t = 1/(1 + px), φ(x) = e^(-x²/2)/√(2π)
        
        uint256 p = 231641900000000000; // 0.2316419
        uint256 b1 = 319381530000000000; // 0.31938153
        uint256 b2 = 356563782000000000; // -0.356563782 (will subtract)
        uint256 b3 = 1781477937000000000; // 1.781477937
        uint256 b4 = 1821255978000000000; // -1.821255978 (will subtract)
        uint256 b5 = 1330274429000000000; // 1.330274429
        
        // Calculate t = 1/(1 + px)
        uint256 denominator = PRECISION + p.mul(ux);
        uint256 t = PRECISION.div(denominator);
        
        // Calculate polynomial: b₁t + b₂t² + b₃t³ + b₄t⁴ + b₅t⁵
        uint256 t2 = t.mul(t);
        uint256 t3 = t2.mul(t);
        uint256 t4 = t3.mul(t);
        uint256 t5 = t4.mul(t);
        
        uint256 poly = b1.mul(t);
        poly = poly > b2.mul(t2) ? poly - b2.mul(t2) : 0;
        poly = poly + b3.mul(t3);
        poly = poly > b4.mul(t4) ? poly - b4.mul(t4) : 0;
        poly = poly + b5.mul(t5);
        
        // Calculate φ(x) = e^(-x²/2)/√(2π)
        uint256 xSquared = ux.mul(ux);
        int256 exponent = -int256(xSquared / 2);
        uint256 expValue = FixedPointMath.exp(exponent);
        uint256 phi = expValue.div(SQRT_2PI);
        
        // N(x) = 1 - φ(x) * poly
        uint256 result = phi.mul(poly);
        return result < PRECISION ? PRECISION - result : 0;
    }

    /**
     * @notice Calculates probability density function φ(x)
     * @param x Input value (18 decimals)
     * @return result φ(x) = e^(-x²/2)/√(2π)
     */
    function normalPDF(int256 x) internal pure returns (uint256) {
        uint256 ux = FixedPointMath.abs(x);
        uint256 xSquared = ux.mul(ux);
        int256 exponent = -int256(xSquared / 2);
        uint256 expValue = FixedPointMath.exp(exponent);
        return expValue.div(SQRT_2PI);
    }

    /**
     * @notice Calculates intrinsic value of an option
     * @param spotPrice Current price
     * @param strikePrice Strike price
     * @param optionType CALL or PUT
     * @return value Intrinsic value
     */
    function intrinsicValue(
        uint256 spotPrice,
        uint256 strikePrice,
        OptionType optionType
    ) internal pure returns (uint256) {
        if (optionType == OptionType.CALL) {
            return spotPrice > strikePrice ? spotPrice - strikePrice : 0;
        } else {
            return strikePrice > spotPrice ? strikePrice - spotPrice : 0;
        }
    }

    /**
     * @notice Checks if option is in-the-money
     * @param spotPrice Current price
     * @param strikePrice Strike price
     * @param optionType CALL or PUT
     * @return True if in-the-money
     */
    function isInTheMoney(
        uint256 spotPrice,
        uint256 strikePrice,
        OptionType optionType
    ) internal pure returns (bool) {
        if (optionType == OptionType.CALL) {
            return spotPrice > strikePrice;
        } else {
            return strikePrice > spotPrice;
        }
    }

    /**
     * @notice Calculates time value of an option
     * @param premium Total option premium
     * @param spotPrice Current price
     * @param strikePrice Strike price
     * @param optionType CALL or PUT
     * @return timeValue Time value component
     */
    function timeValue(
        uint256 premium,
        uint256 spotPrice,
        uint256 strikePrice,
        OptionType optionType
    ) internal pure returns (uint256) {
        uint256 intrinsic = intrinsicValue(spotPrice, strikePrice, optionType);
        return premium > intrinsic ? premium - intrinsic : 0;
    }
}
