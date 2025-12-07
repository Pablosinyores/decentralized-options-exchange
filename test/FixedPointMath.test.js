const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FixedPointMath Library - Comprehensive Test Suite", function () {
  let fixedPointMathTest;
  const PRECISION = ethers.utils.parseEther("1");

  before(async function () {
    const FixedPointMathTest = await ethers.getContractFactory("FixedPointMathTest");
    fixedPointMathTest = await FixedPointMathTest.deploy();
    await fixedPointMathTest.deployed();
  });

  describe("Basic Arithmetic", function () {
    it("Should multiply two numbers correctly", async function () {
      const a = ethers.utils.parseEther("2.5");
      const b = ethers.utils.parseEther("4");
      const result = await fixedPointMathTest.testMul(a, b);
      expect(result).to.equal(ethers.utils.parseEther("10"));
    });

    it("Should handle multiplication by zero", async function () {
      const a = ethers.utils.parseEther("5");
      const b = 0;
      const result = await fixedPointMathTest.testMul(a, b);
      expect(result).to.equal(0);
    });

    it("Should divide two numbers correctly", async function () {
      const a = ethers.utils.parseEther("10");
      const b = ethers.utils.parseEther("2");
      const result = await fixedPointMathTest.testDiv(a, b);
      expect(result).to.equal(ethers.utils.parseEther("5"));
    });

    it("Should revert on division by zero", async function () {
      const a = ethers.utils.parseEther("10");
      await expect(
        fixedPointMathTest.testDiv(a, 0)
      ).to.be.revertedWith("Division by zero");
    });

    it("Should add two numbers correctly", async function () {
      const a = ethers.utils.parseEther("3.5");
      const b = ethers.utils.parseEther("2.5");
      const result = await fixedPointMathTest.testAdd(a, b);
      expect(result).to.equal(ethers.utils.parseEther("6"));
    });

    it("Should subtract two numbers correctly", async function () {
      const a = ethers.utils.parseEther("5");
      const b = ethers.utils.parseEther("3");
      const result = await fixedPointMathTest.testSub(a, b);
      expect(result).to.equal(ethers.utils.parseEther("2"));
    });

    it("Should revert on subtraction underflow", async function () {
      const a = ethers.utils.parseEther("3");
      const b = ethers.utils.parseEther("5");
      await expect(
        fixedPointMathTest.testSub(a, b)
      ).to.be.revertedWith("Subtraction underflow");
    });
  });

  describe("Exponential Function", function () {
    it("Should calculate e^0 = 1", async function () {
      const result = await fixedPointMathTest.testExp(0);
      expect(result).to.be.closeTo(PRECISION, PRECISION.div(1000));
    });

    it("Should calculate e^1 ≈ 2.718", async function () {
      const result = await fixedPointMathTest.testExp(PRECISION);
      const expected = ethers.utils.parseEther("2.718281828");
      expect(result).to.be.closeTo(expected, expected.div(1000));
    });

    it("Should calculate e^2 ≈ 7.389", async function () {
      const x = PRECISION.mul(2);
      const result = await fixedPointMathTest.testExp(x);
      const expected = ethers.utils.parseEther("7.389");
      expect(result).to.be.closeTo(expected, expected.div(100));
    });

    it("Should calculate e^(-1) ≈ 0.368", async function () {
      const x = PRECISION.mul(-1);
      const result = await fixedPointMathTest.testExp(x);
      const expected = ethers.utils.parseEther("0.368");
      expect(result).to.be.closeTo(expected, expected.div(100));
    });

    it("Should handle small positive exponents", async function () {
      const x = ethers.utils.parseEther("0.1");
      const result = await fixedPointMathTest.testExp(x);
      const expected = ethers.utils.parseEther("1.105");
      expect(result).to.be.closeTo(expected, expected.div(100));
    });

    it("Should handle small negative exponents", async function () {
      const x = ethers.utils.parseEther("-0.1");
      const result = await fixedPointMathTest.testExp(x);
      const expected = ethers.utils.parseEther("0.905");
      expect(result).to.be.closeTo(expected, expected.div(100));
    });
  });

  describe("Natural Logarithm", function () {
    it("Should calculate ln(1) = 0", async function () {
      const result = await fixedPointMathTest.testLn(PRECISION);
      expect(result).to.be.closeTo(0, 1000);
    });

    it("Should calculate ln(e) ≈ 1", async function () {
      const e = ethers.utils.parseEther("2.718281828");
      const result = await fixedPointMathTest.testLn(e);
      expect(result).to.be.closeTo(PRECISION, PRECISION.div(100));
    });

    it("Should calculate ln(2) ≈ 0.693", async function () {
      const x = PRECISION.mul(2);
      const result = await fixedPointMathTest.testLn(x);
      const expected = ethers.utils.parseEther("0.693");
      expect(result).to.be.closeTo(expected, expected.div(100));
    });

    it("Should calculate ln(10) ≈ 2.303", async function () {
      const x = PRECISION.mul(10);
      const result = await fixedPointMathTest.testLn(x);
      const expected = ethers.utils.parseEther("2.303");
      expect(result).to.be.closeTo(expected, expected.div(100));
    });

    it("Should revert for ln(0)", async function () {
      await expect(
        fixedPointMathTest.testLn(0)
      ).to.be.revertedWith("ln(0) undefined");
    });

    it("Should handle values close to 1", async function () {
      const x = ethers.utils.parseEther("1.1");
      const result = await fixedPointMathTest.testLn(x);
      const expected = ethers.utils.parseEther("0.095");
      expect(result).to.be.closeTo(expected, expected.div(10));
    });
  });

  describe("Square Root", function () {
    it("Should calculate sqrt(0) = 0", async function () {
      const result = await fixedPointMathTest.testSqrt(0);
      expect(result).to.equal(0);
    });

    it("Should calculate sqrt(1) = 1", async function () {
      const result = await fixedPointMathTest.testSqrt(PRECISION);
      expect(result).to.equal(PRECISION);
    });

    it("Should calculate sqrt(4) = 2", async function () {
      const x = PRECISION.mul(4);
      const result = await fixedPointMathTest.testSqrt(x);
      expect(result).to.equal(PRECISION.mul(2));
    });

    it("Should calculate sqrt(2) ≈ 1.414", async function () {
      const x = PRECISION.mul(2);
      const result = await fixedPointMathTest.testSqrt(x);
      const expected = ethers.utils.parseEther("1.414");
      expect(result).to.be.closeTo(expected, expected.div(1000));
    });

    it("Should calculate sqrt(0.25) = 0.5", async function () {
      const x = ethers.utils.parseEther("0.25");
      const result = await fixedPointMathTest.testSqrt(x);
      expect(result).to.equal(ethers.utils.parseEther("0.5"));
    });

    it("Should handle very small numbers", async function () {
      const x = ethers.utils.parseEther("0.0001");
      const result = await fixedPointMathTest.testSqrt(x);
      const expected = ethers.utils.parseEther("0.01");
      expect(result).to.be.closeTo(expected, expected.div(100));
    });

    it("Should handle very large numbers", async function () {
      const x = ethers.utils.parseEther("1000000");
      const result = await fixedPointMathTest.testSqrt(x);
      const expected = ethers.utils.parseEther("1000");
      expect(result).to.be.closeTo(expected, expected.div(100));
    });
  });

  describe("Power Function", function () {
    it("Should calculate x^0 = 1", async function () {
      const x = ethers.utils.parseEther("5");
      const result = await fixedPointMathTest.testPow(x, 0);
      expect(result).to.equal(PRECISION);
    });

    it("Should calculate 0^y = 0 (for y > 0)", async function () {
      const result = await fixedPointMathTest.testPow(0, 5);
      expect(result).to.equal(0);
    });

    it("Should calculate 2^3 = 8", async function () {
      const x = PRECISION.mul(2);
      const result = await fixedPointMathTest.testPow(x, 3);
      expect(result).to.equal(PRECISION.mul(8));
    });

    it("Should calculate 1.5^2 = 2.25", async function () {
      const x = ethers.utils.parseEther("1.5");
      const result = await fixedPointMathTest.testPow(x, 2);
      expect(result).to.equal(ethers.utils.parseEther("2.25"));
    });

    it("Should calculate 0.5^3 = 0.125", async function () {
      const x = ethers.utils.parseEther("0.5");
      const result = await fixedPointMathTest.testPow(x, 3);
      expect(result).to.equal(ethers.utils.parseEther("0.125"));
    });
  });

  describe("Utility Functions", function () {
    it("Should convert to fixed-point correctly", async function () {
      const result = await fixedPointMathTest.testToFixed(5);
      expect(result).to.equal(PRECISION.mul(5));
    });

    it("Should convert from fixed-point correctly", async function () {
      const x = ethers.utils.parseEther("5.7");
      const result = await fixedPointMathTest.testFromFixed(x);
      expect(result).to.equal(5);
    });

    it("Should round correctly (down)", async function () {
      const x = ethers.utils.parseEther("5.4");
      const result = await fixedPointMathTest.testRound(x);
      expect(result).to.equal(5);
    });

    it("Should round correctly (up)", async function () {
      const x = ethers.utils.parseEther("5.6");
      const result = await fixedPointMathTest.testRound(x);
      expect(result).to.equal(6);
    });

    it("Should round correctly (exactly 0.5)", async function () {
      const x = ethers.utils.parseEther("5.5");
      const result = await fixedPointMathTest.testRound(x);
      expect(result).to.equal(6);
    });

    it("Should calculate absolute value for positive", async function () {
      const result = await fixedPointMathTest.testAbs(PRECISION.mul(5));
      expect(result).to.equal(PRECISION.mul(5));
    });

    it("Should calculate absolute value for negative", async function () {
      const result = await fixedPointMathTest.testAbs(PRECISION.mul(-5));
      expect(result).to.equal(PRECISION.mul(5));
    });
  });

  describe("Edge Cases & Precision", function () {
    it("Should maintain precision in complex calculations", async function () {
      // (2.5 * 3.7) / 1.3 ≈ 7.115
      const a = ethers.utils.parseEther("2.5");
      const b = ethers.utils.parseEther("3.7");
      const c = ethers.utils.parseEther("1.3");
      
      const mul = await fixedPointMathTest.testMul(a, b);
      const result = await fixedPointMathTest.testDiv(mul, c);
      
      const expected = ethers.utils.parseEther("7.115");
      expect(result).to.be.closeTo(expected, expected.div(100));
    });

    it("Should handle very small multiplications", async function () {
      const a = ethers.utils.parseEther("0.0001");
      const b = ethers.utils.parseEther("0.0001");
      const result = await fixedPointMathTest.testMul(a, b);
      const expected = ethers.utils.parseEther("0.00000001");
      expect(result).to.be.closeTo(expected, 1000);
    });

    it("Should handle very large divisions", async function () {
      const a = ethers.utils.parseEther("1000000");
      const b = ethers.utils.parseEther("0.001");
      const result = await fixedPointMathTest.testDiv(a, b);
      const expected = ethers.utils.parseEther("1000000000");
      expect(result).to.be.closeTo(expected, expected.div(1000));
    });
  });
});
