// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/FixedPointMath.sol";
import "./BlackScholes.sol";

/**
 * @title GreeksCalculator
 * @notice Calculates option Greeks (Delta, Gamma, Theta, Vega, Rho)
 * @dev Greeks measure sensitivity of option price to various parameters
 * 
 * Greeks:
 * - Delta (Δ): Rate of change of option price with respect to underlying price
 * - Gamma (Γ): Rate of change of delta with respect to underlying price
 * - Theta (Θ): Rate of change of option price with respect to time
 * - Vega (ν): Rate of change of option price with respect to volatility
 * - Rho (ρ): Rate of change of option price with respect to interest rate
 */
library GreeksCalculator {
    using FixedPointMath for uint256;
    using FixedPointMath for int256;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant SQRT_2PI = 2506628274631000502;

    /**
     * @notice Calculates Delta (∂V/∂S)
     * @param params Option parameters
     * @param optionType CALL or PUT
     * @return delta Delta value (18 decimals)
     * 
     * @dev Call Delta: N(d₁)
     *      Put Delta: N(d₁) - 1
     */
    function calculateDelta(
        BlackScholes.OptionParams memory params,
        BlackScholes.OptionType optionType
    ) internal pure returns (int256 delta) {
        (int256 d1, ) = BlackScholes.calculateD1D2(params);
        uint256 Nd1 = BlackScholes.cumulativeNormalDistribution(d1);
        
        if (optionType == BlackScholes.OptionType.CALL) {
            delta = int256(Nd1);
        } else {
            delta = int256(Nd1) - int256(PRECISION);
        }
    }

    /**
     * @notice Calculates Gamma (∂²V/∂S²)
     * @param params Option parameters
     * @return gamma Gamma value (18 decimals)
     * 
     * @dev Γ = φ(d₁) / (S₀σ√T)
     *      Same for both calls and puts
     */
    function calculateGamma(
        BlackScholes.OptionParams memory params
    ) internal pure returns (uint256 gamma) {
        (int256 d1, ) = BlackScholes.calculateD1D2(params);
        
        // Calculate φ(d₁)
        uint256 phi = BlackScholes.normalPDF(d1);
        
        // Calculate σ√T
        uint256 timeInYears = (params.timeToExpiry * PRECISION) / 365 days;
        uint256 sqrtTime = FixedPointMath.sqrt(timeInYears);
        uint256 volSqrtTime = params.volatility.mul(sqrtTime);
        
        // Γ = φ(d₁) / (S₀σ√T)
        uint256 denominator = params.spotPrice.mul(volSqrtTime);
        require(denominator > 0, "Invalid denominator");
        
        gamma = phi.div(denominator);
    }

    /**
     * @notice Calculates Theta (∂V/∂t)
     * @param params Option parameters
     * @param optionType CALL or PUT
     * @return theta Theta value per day (18 decimals)
     * 
     * @dev Call Θ = -[S₀φ(d₁)σ/(2√T)] - rKe^(-rT)N(d₂)
     *      Put Θ = -[S₀φ(d₁)σ/(2√T)] + rKe^(-rT)N(-d₂)
     */
    function calculateTheta(
        BlackScholes.OptionParams memory params,
        BlackScholes.OptionType optionType
    ) internal pure returns (int256 theta) {
        (int256 d1, int256 d2) = BlackScholes.calculateD1D2(params);
        
        // Calculate time components
        uint256 timeInYears = (params.timeToExpiry * PRECISION) / 365 days;
        uint256 sqrtTime = FixedPointMath.sqrt(timeInYears);
        
        // Calculate φ(d₁)
        uint256 phi = BlackScholes.normalPDF(d1);
        
        // Calculate first term: -S₀φ(d₁)σ/(2√T)
        uint256 term1Numerator = params.spotPrice.mul(phi).mul(params.volatility);
        uint256 term1Denominator = 2 * sqrtTime;
        int256 term1 = -int256(term1Numerator.div(term1Denominator));
        
        // Calculate discount factor: e^(-rT)
        int256 exponent = -int256(params.riskFreeRate.mul(timeInYears));
        uint256 discountFactor = FixedPointMath.exp(exponent);
        
        int256 term2;
        if (optionType == BlackScholes.OptionType.CALL) {
            // -rKe^(-rT)N(d₂)
            uint256 Nd2 = BlackScholes.cumulativeNormalDistribution(d2);
            uint256 term2Value = params.riskFreeRate.mul(params.strikePrice).mul(discountFactor).mul(Nd2);
            term2 = -int256(term2Value);
        } else {
            // +rKe^(-rT)N(-d₂)
            uint256 NminusD2 = PRECISION - BlackScholes.cumulativeNormalDistribution(d2);
            uint256 term2Value = params.riskFreeRate.mul(params.strikePrice).mul(discountFactor).mul(NminusD2);
            term2 = int256(term2Value);
        }
        
        // Theta per year, convert to per day
        theta = (term1 + term2) / 365;
    }

    /**
     * @notice Calculates Vega (∂V/∂σ)
     * @param params Option parameters
     * @return vega Vega value (18 decimals)
     * 
     * @dev ν = S₀φ(d₁)√T
     *      Same for both calls and puts
     */
    function calculateVega(
        BlackScholes.OptionParams memory params
    ) internal pure returns (uint256 vega) {
        (int256 d1, ) = BlackScholes.calculateD1D2(params);
        
        // Calculate φ(d₁)
        uint256 phi = BlackScholes.normalPDF(d1);
        
        // Calculate √T
        uint256 timeInYears = (params.timeToExpiry * PRECISION) / 365 days;
        uint256 sqrtTime = FixedPointMath.sqrt(timeInYears);
        
        // ν = S₀φ(d₁)√T
        vega = params.spotPrice.mul(phi).mul(sqrtTime);
        
        // Vega is typically expressed per 1% change in volatility
        vega = vega / 100;
    }

    /**
     * @notice Calculates Rho (∂V/∂r)
     * @param params Option parameters
     * @param optionType CALL or PUT
     * @return rho Rho value (18 decimals)
     * 
     * @dev Call ρ = KTe^(-rT)N(d₂)
     *      Put ρ = -KTe^(-rT)N(-d₂)
     */
    function calculateRho(
        BlackScholes.OptionParams memory params,
        BlackScholes.OptionType optionType
    ) internal pure returns (int256 rho) {
        (, int256 d2) = BlackScholes.calculateD1D2(params);
        
        // Calculate time in years
        uint256 timeInYears = (params.timeToExpiry * PRECISION) / 365 days;
        
        // Calculate discount factor: e^(-rT)
        int256 exponent = -int256(params.riskFreeRate.mul(timeInYears));
        uint256 discountFactor = FixedPointMath.exp(exponent);
        
        if (optionType == BlackScholes.OptionType.CALL) {
            // KTe^(-rT)N(d₂)
            uint256 Nd2 = BlackScholes.cumulativeNormalDistribution(d2);
            uint256 rhoValue = params.strikePrice.mul(timeInYears).mul(discountFactor).mul(Nd2);
            rho = int256(rhoValue);
        } else {
            // -KTe^(-rT)N(-d₂)
            uint256 NminusD2 = PRECISION - BlackScholes.cumulativeNormalDistribution(d2);
            uint256 rhoValue = params.strikePrice.mul(timeInYears).mul(discountFactor).mul(NminusD2);
            rho = -int256(rhoValue);
        }
        
        // Rho is typically expressed per 1% change in interest rate
        rho = rho / 100;
    }

    /**
     * @notice Calculates all Greeks at once
     * @param params Option parameters
     * @param optionType CALL or PUT
     * @return delta Delta value
     * @return gamma Gamma value
     * @return theta Theta value (per day)
     * @return vega Vega value (per 1% vol)
     * @return rho Rho value (per 1% rate)
     */
    function calculateAllGreeks(
        BlackScholes.OptionParams memory params,
        BlackScholes.OptionType optionType
    ) internal pure returns (
        int256 delta,
        uint256 gamma,
        int256 theta,
        uint256 vega,
        int256 rho
    ) {
        delta = calculateDelta(params, optionType);
        gamma = calculateGamma(params);
        theta = calculateTheta(params, optionType);
        vega = calculateVega(params);
        rho = calculateRho(params, optionType);
    }

    /**
     * @notice Calculates Lambda (leverage/elasticity)
     * @param params Option parameters
     * @param optionType CALL or PUT
     * @param optionPrice Current option price
     * @return lambda Lambda value
     * 
     * @dev Λ = (∂V/∂S) × (S/V) = Δ × (S/V)
     */
    function calculateLambda(
        BlackScholes.OptionParams memory params,
        BlackScholes.OptionType optionType,
        uint256 optionPrice
    ) internal pure returns (int256 lambda) {
        require(optionPrice > 0, "Invalid option price");
        
        int256 delta = calculateDelta(params, optionType);
        
        // Λ = Δ × (S/V)
        uint256 ratio = params.spotPrice.div(optionPrice);
        lambda = (delta * int256(ratio)) / int256(PRECISION);
    }
}
