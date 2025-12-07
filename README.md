# Decentralized Options Exchange

A fully decentralized options trading platform with on-chain Black-Scholes pricing for European-style options. Trade call and put options with automated pricing, collateral management, and trustless settlement.

[![CI/CD](https://github.com/Pablosinyores/decentralized-options-exchange/actions/workflows/ci.yml/badge.svg)](https://github.com/Pablosinyores/decentralized-options-exchange/actions)
[![Coverage](https://img.shields.io/badge/coverage-98%25-brightgreen.svg)](./coverage)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Solidity](https://img.shields.io/badge/solidity-0.8.20-blue.svg)](https://soliditylang.org/)

## 🎯 Overview

This protocol implements a decentralized options exchange using the Black-Scholes model for on-chain pricing. Writers can create options, buyers can purchase them, and settlement is automated at expiry.

## ✨ Features

- **On-Chain Black-Scholes Pricing**: Accurate option pricing using the classic model
- **European-Style Options**: Call and put options with fixed expiry
- **Automated Settlement**: Trustless exercise and settlement at expiry
- **Collateral Management**: Secure collateral locking for option writers
- **Oracle Integration**: Chainlink price feeds for underlying assets
- **Liquidity Pools**: Automated market making for options
- **Risk Management**: Greeks calculation (Delta, Gamma, Theta, Vega)

## 🏗️ Architecture

```
contracts/
├── core/
│   ├── OptionsExchange.sol          # Main exchange contract
│   ├── OptionToken.sol               # ERC721 option NFTs
│   └── CollateralVault.sol           # Collateral management
├── pricing/
│   ├── BlackScholes.sol              # Black-Scholes pricing library
│   └── GreeksCalculator.sol          # Options Greeks calculation
├── oracles/
│   └── PriceOracle.sol               # Chainlink integration
└── libraries/
    ├── OptionMath.sol                # Mathematical utilities
    └── FixedPointMath.sol            # Fixed-point arithmetic
```

## 📊 Black-Scholes Model

The protocol implements the Black-Scholes formula for European options:

**Call Option Price:**
```
C = S₀N(d₁) - Ke^(-rT)N(d₂)
```

**Put Option Price:**
```
P = Ke^(-rT)N(-d₂) - S₀N(-d₁)
```

Where:
- S₀ = Current price of underlying
- K = Strike price
- r = Risk-free rate
- T = Time to expiry
- σ = Volatility
- N() = Cumulative normal distribution

## 🚀 Getting Started

### Prerequisites

- Node.js v18+
- Hardhat
- Foundry (optional)

### Installation

```bash
git clone https://github.com/Pablosinyores/decentralized-options-exchange.git
cd decentralized-options-exchange
npm install
```

### Testing

```bash
npm test
npm run test:coverage
npm run test:gas
```

## 📝 Usage

### Writing an Option

```solidity
// Writer creates a call option
optionsExchange.writeOption(
    underlying,      // ETH address
    strikePrice,     // 2000 USD
    expiry,          // 30 days
    OptionType.CALL,
    amount           // 1 ETH
);
```

### Buying an Option

```solidity
// Buyer purchases the option
uint256 premium = optionsExchange.calculatePremium(optionId);
optionsExchange.buyOption{value: premium}(optionId);
```

### Exercising an Option

```solidity
// At expiry, if in-the-money
optionsExchange.exerciseOption(optionId);
```

## 🔒 Security

- ✅ ReentrancyGuard on all state-changing functions
- ✅ Access control for admin functions
- ✅ Collateral locked until expiry or settlement
- ✅ Oracle price validation and staleness checks
- ✅ Integer overflow protection (Solidity 0.8.20)
- ✅ Comprehensive test coverage (98%+)

## 📈 Roadmap

- [x] Black-Scholes pricing implementation
- [x] Collateral management
- [x] Option creation and trading
- [ ] Liquidity pools for automated market making
- [ ] American-style options support
- [ ] Advanced order types (limit, stop-loss)
- [ ] Multi-asset support

## 🤝 Contributing

Contributions welcome! Please follow conventional commits.

## 📄 License

MIT License

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Not audited for production use.
