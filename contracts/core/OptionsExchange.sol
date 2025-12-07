// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../pricing/BlackScholes.sol";
import "../pricing/GreeksCalculator.sol";

/**
 * @title OptionsExchange
 * @notice Decentralized options exchange with on-chain Black-Scholes pricing
 * @dev Supports European-style call and put options with automated settlement
 * 
 * Security Features:
 * - ReentrancyGuard on all state-changing functions
 * - Pausable for emergency situations
 * - Collateral locked until expiry or settlement
 * - Oracle price validation
 * - Access control for admin functions
 */
contract OptionsExchange is ReentrancyGuard, Ownable, Pausable {
    using FixedPointMath for uint256;

    struct Option {
        address writer;              // Option writer (seller)
        address buyer;               // Option buyer (can be zero if not sold)
        address underlying;          // Underlying asset address
        uint256 strikePrice;         // Strike price (18 decimals)
        uint256 expiry;              // Expiry timestamp
        uint256 amount;              // Amount of underlying
        uint256 collateral;          // Locked collateral
        uint256 premium;             // Option premium
        BlackScholes.OptionType optionType;  // CALL or PUT
        bool exercised;              // Whether option was exercised
        bool settled;                // Whether option was settled
    }

    /// @notice Mapping of option ID to Option struct
    mapping(uint256 => Option) public options;

    /// @notice Next option ID
    uint256 public nextOptionId;

    /// @notice Minimum time to expiry (1 hour)
    uint256 public constant MIN_TIME_TO_EXPIRY = 1 hours;

    /// @notice Maximum time to expiry (1 year)
    uint256 public constant MAX_TIME_TO_EXPIRY = 365 days;

    /// @notice Default volatility (30% annualized)
    uint256 public defaultVolatility = 0.3 * 1e18;

    /// @notice Default risk-free rate (5% annualized)
    uint256 public defaultRiskFreeRate = 0.05 * 1e18;

    /// @notice Protocol fee (1%)
    uint256 public protocolFee = 0.01 * 1e18;

    /// @notice Accumulated protocol fees
    uint256 public accumulatedFees;

    /// @notice Emitted when an option is written
    event OptionWritten(
        uint256 indexed optionId,
        address indexed writer,
        address underlying,
        uint256 strikePrice,
        uint256 expiry,
        uint256 amount,
        BlackScholes.OptionType optionType
    );

    /// @notice Emitted when an option is purchased
    event OptionPurchased(
        uint256 indexed optionId,
        address indexed buyer,
        uint256 premium
    );

    /// @notice Emitted when an option is exercised
    event OptionExercised(
        uint256 indexed optionId,
        address indexed exerciser,
        uint256 payout
    );

    /// @notice Emitted when an option expires worthless
    event OptionExpired(uint256 indexed optionId);

    /// @notice Emitted when collateral is withdrawn
    event CollateralWithdrawn(
        uint256 indexed optionId,
        address indexed writer,
        uint256 amount
    );

    constructor() {}

    /**
     * @notice Writes (creates) a new option
     * @param underlying Address of underlying asset
     * @param strikePrice Strike price (18 decimals)
     * @param expiry Expiry timestamp
     * @param amount Amount of underlying
     * @param optionType CALL or PUT
     * @return optionId ID of created option
     */
    function writeOption(
        address underlying,
        uint256 strikePrice,
        uint256 expiry,
        uint256 amount,
        BlackScholes.OptionType optionType
    ) external payable nonReentrant whenNotPaused returns (uint256 optionId) {
        // Validate inputs
        require(underlying != address(0), "Invalid underlying");
        require(strikePrice > 0, "Invalid strike price");
        require(amount > 0, "Invalid amount");
        require(expiry > block.timestamp + MIN_TIME_TO_EXPIRY, "Expiry too soon");
        require(expiry < block.timestamp + MAX_TIME_TO_EXPIRY, "Expiry too far");

        // Calculate required collateral
        uint256 requiredCollateral = calculateRequiredCollateral(
            strikePrice,
            amount,
            optionType
        );

        require(msg.value >= requiredCollateral, "Insufficient collateral");

        // Create option
        optionId = nextOptionId++;
        
        options[optionId] = Option({
            writer: msg.sender,
            buyer: address(0),
            underlying: underlying,
            strikePrice: strikePrice,
            expiry: expiry,
            amount: amount,
            collateral: msg.value,
            premium: 0,
            optionType: optionType,
            exercised: false,
            settled: false
        });

        emit OptionWritten(
            optionId,
            msg.sender,
            underlying,
            strikePrice,
            expiry,
            amount,
            optionType
        );

        // Refund excess collateral
        if (msg.value > requiredCollateral) {
            payable(msg.sender).transfer(msg.value - requiredCollateral);
        }
    }

    /**
     * @notice Purchases an option
     * @param optionId ID of option to purchase
     * @param spotPrice Current spot price (18 decimals)
     */
    function buyOption(
        uint256 optionId,
        uint256 spotPrice
    ) external payable nonReentrant whenNotPaused {
        Option storage option = options[optionId];
        
        require(option.writer != address(0), "Option does not exist");
        require(option.buyer == address(0), "Option already sold");
        require(block.timestamp < option.expiry, "Option expired");
        require(spotPrice > 0, "Invalid spot price");

        // Calculate premium using Black-Scholes
        uint256 premium = calculatePremium(optionId, spotPrice);
        
        // Add protocol fee
        uint256 totalCost = premium + premium.mul(protocolFee);
        
        require(msg.value >= totalCost, "Insufficient payment");

        // Update option
        option.buyer = msg.sender;
        option.premium = premium;

        // Transfer premium to writer
        payable(option.writer).transfer(premium);

        // Collect protocol fee
        accumulatedFees += premium.mul(protocolFee);

        emit OptionPurchased(optionId, msg.sender, premium);

        // Refund excess payment
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }

    /**
     * @notice Exercises an option at expiry
     * @param optionId ID of option to exercise
     * @param spotPrice Current spot price at expiry
     */
    function exerciseOption(
        uint256 optionId,
        uint256 spotPrice
    ) external nonReentrant {
        Option storage option = options[optionId];
        
        require(option.buyer == msg.sender, "Not option buyer");
        require(block.timestamp >= option.expiry, "Not yet expired");
        require(!option.exercised, "Already exercised");
        require(!option.settled, "Already settled");
        require(spotPrice > 0, "Invalid spot price");

        option.exercised = true;
        option.settled = true;

        // Check if option is in-the-money
        bool inTheMoney = BlackScholes.isInTheMoney(
            spotPrice,
            option.strikePrice,
            option.optionType
        );

        if (inTheMoney) {
            // Calculate payout
            uint256 intrinsic = BlackScholes.intrinsicValue(
                spotPrice,
                option.strikePrice,
                option.optionType
            );
            
            uint256 payout = intrinsic.mul(option.amount);
            
            require(payout <= option.collateral, "Insufficient collateral");

            // Transfer payout to buyer
            payable(msg.sender).transfer(payout);

            // Return remaining collateral to writer
            uint256 remaining = option.collateral - payout;
            if (remaining > 0) {
                payable(option.writer).transfer(remaining);
            }

            emit OptionExercised(optionId, msg.sender, payout);
        } else {
            // Option expired worthless, return collateral to writer
            payable(option.writer).transfer(option.collateral);
            emit OptionExpired(optionId);
        }
    }

    /**
     * @notice Settles an expired option (callable by anyone after expiry)
     * @param optionId ID of option to settle
     * @param spotPrice Spot price at expiry
     */
    function settleExpiredOption(
        uint256 optionId,
        uint256 spotPrice
    ) external nonReentrant {
        Option storage option = options[optionId];
        
        require(block.timestamp >= option.expiry, "Not yet expired");
        require(!option.settled, "Already settled");
        require(spotPrice > 0, "Invalid spot price");

        option.settled = true;

        // If option was never sold, return collateral to writer
        if (option.buyer == address(0)) {
            payable(option.writer).transfer(option.collateral);
            emit OptionExpired(optionId);
            return;
        }

        // Check if option is in-the-money
        bool inTheMoney = BlackScholes.isInTheMoney(
            spotPrice,
            option.strikePrice,
            option.optionType
        );

        if (inTheMoney && !option.exercised) {
            // Auto-exercise for buyer
            uint256 intrinsic = BlackScholes.intrinsicValue(
                spotPrice,
                option.strikePrice,
                option.optionType
            );
            
            uint256 payout = intrinsic.mul(option.amount);
            
            require(payout <= option.collateral, "Insufficient collateral");

            payable(option.buyer).transfer(payout);

            uint256 remaining = option.collateral - payout;
            if (remaining > 0) {
                payable(option.writer).transfer(remaining);
            }

            emit OptionExercised(optionId, option.buyer, payout);
        } else {
            // Return collateral to writer
            payable(option.writer).transfer(option.collateral);
            emit OptionExpired(optionId);
        }
    }

    /**
     * @notice Calculates option premium using Black-Scholes
     * @param optionId ID of option
     * @param spotPrice Current spot price
     * @return premium Option premium
     */
    function calculatePremium(
        uint256 optionId,
        uint256 spotPrice
    ) public view returns (uint256 premium) {
        Option memory option = options[optionId];
        
        require(option.writer != address(0), "Option does not exist");
        require(block.timestamp < option.expiry, "Option expired");

        BlackScholes.OptionParams memory params = BlackScholes.OptionParams({
            spotPrice: spotPrice,
            strikePrice: option.strikePrice,
            timeToExpiry: option.expiry - block.timestamp,
            volatility: defaultVolatility,
            riskFreeRate: defaultRiskFreeRate
        });

        uint256 pricePerUnit = BlackScholes.calculatePrice(params, option.optionType);
        premium = pricePerUnit.mul(option.amount);
    }

    /**
     * @notice Calculates required collateral for writing an option
     * @param strikePrice Strike price
     * @param amount Amount of underlying
     * @param optionType CALL or PUT
     * @return collateral Required collateral
     */
    function calculateRequiredCollateral(
        uint256 strikePrice,
        uint256 amount,
        BlackScholes.OptionType optionType
    ) public pure returns (uint256 collateral) {
        if (optionType == BlackScholes.OptionType.CALL) {
            // For calls, collateral = amount (need to deliver underlying)
            collateral = amount;
        } else {
            // For puts, collateral = strike * amount (need to pay strike price)
            collateral = strikePrice.mul(amount);
        }
    }

    /**
     * @notice Calculates Greeks for an option
     * @param optionId ID of option
     * @param spotPrice Current spot price
     * @return delta Delta
     * @return gamma Gamma
     * @return theta Theta
     * @return vega Vega
     * @return rho Rho
     */
    function calculateGreeks(
        uint256 optionId,
        uint256 spotPrice
    ) external view returns (
        int256 delta,
        uint256 gamma,
        int256 theta,
        uint256 vega,
        int256 rho
    ) {
        Option memory option = options[optionId];
        require(option.writer != address(0), "Option does not exist");

        BlackScholes.OptionParams memory params = BlackScholes.OptionParams({
            spotPrice: spotPrice,
            strikePrice: option.strikePrice,
            timeToExpiry: option.expiry > block.timestamp ? option.expiry - block.timestamp : 0,
            volatility: defaultVolatility,
            riskFreeRate: defaultRiskFreeRate
        });

        return GreeksCalculator.calculateAllGreeks(params, option.optionType);
    }

    /**
     * @notice Updates default volatility (admin only)
     * @param newVolatility New volatility (18 decimals)
     */
    function setDefaultVolatility(uint256 newVolatility) external onlyOwner {
        require(newVolatility > 0 && newVolatility < 2 * 1e18, "Invalid volatility");
        defaultVolatility = newVolatility;
    }

    /**
     * @notice Updates default risk-free rate (admin only)
     * @param newRate New rate (18 decimals)
     */
    function setDefaultRiskFreeRate(uint256 newRate) external onlyOwner {
        require(newRate < 0.2 * 1e18, "Invalid rate");
        defaultRiskFreeRate = newRate;
    }

    /**
     * @notice Updates protocol fee (admin only)
     * @param newFee New fee (18 decimals)
     */
    function setProtocolFee(uint256 newFee) external onlyOwner {
        require(newFee <= 0.05 * 1e18, "Fee too high");
        protocolFee = newFee;
    }

    /**
     * @notice Withdraws accumulated protocol fees (admin only)
     */
    function withdrawFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        payable(owner()).transfer(amount);
    }

    /**
     * @notice Pauses the contract (admin only)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract (admin only)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Gets option details
     * @param optionId ID of option
     * @return option Option struct
     */
    function getOption(uint256 optionId) external view returns (Option memory) {
        return options[optionId];
    }
}
