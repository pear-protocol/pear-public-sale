// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title PublicSale
 * @dev A smart contract for a token public sale.
 */
contract PublicSale is Ownable {
    using SafeMath for uint256;

    IERC20 public usdcToken;

    // max token for public sale: 100mm
    uint256 public immutable tokensForSale = 100_000_000 * 1e18;

    // price per token is 0.025 USDC
    uint256 public immutable pricePerToken = 25 * 1e3;

    // april 24th, 2023 12:00:00 UTC
    uint40 public saleEndEpoch = 1682337600;

    mapping(address => uint256) public tokenBalances;
    uint256 public totalTokensSold;

    error SaleIsOver();
    error SaleIsStillOngoing();
    error AmountIsTooLow();

    /**
     * @dev Constructor that sets the initial contract parameters.
     * @param _usdcToken The address of the USDC token contract.
     * @param _owner The address of the owner.
     */
    constructor(address _usdcToken, address _owner) {
        usdcToken = IERC20(_usdcToken);
        transferOwnership(_owner);
    }

    /**
     * @dev Modifier that checks if the sale is still ongoing.
     */
    modifier duringSale() {
        if (block.timestamp > saleEndEpoch) revert SaleIsOver();
        _;
    }

    /**
     * @dev Modifier that checks if the sale has ended.
     */
    modifier afterSale() {
        if (block.timestamp <= saleEndEpoch) revert SaleIsStillOngoing();
        _;
    }

    /**
     * @dev Function that allows users to preview the amount of tokens they will get.
     * @param _usdcAmount The amount of USDC to spend.
     */
    function previewBuyTokens(
        uint256 _usdcAmount
    ) public pure returns (uint256) {
        // example calculation: buy 1 USDC worth of tokens (40)
        return _usdcAmount.div(pricePerToken).mul(1e18);
    }

    /**
     * @dev Function that allows users to buy tokens.
     * @param _usdcAmount The amount of USDC to spend.
     */
    function buyTokens(uint256 _usdcAmount) external duringSale {
        uint256 tokenAmount = previewBuyTokens(_usdcAmount);
        require(
            totalTokensSold.add(tokenAmount) <= tokensForSale,
            "Exceeds sale allocation"
        );
        if (tokenAmount <= 1) revert AmountIsTooLow();
        require(
            usdcToken.transferFrom(msg.sender, address(this), _usdcAmount),
            "Transfer failed"
        );
        tokenBalances[msg.sender] = tokenBalances[msg.sender].add(tokenAmount);
        totalTokensSold = totalTokensSold.add(tokenAmount);
    }

    /**
     * @dev Function that allows the owner to extend the sale duration by 7 days.
     */
    function extendSale() external onlyOwner duringSale {
        saleEndEpoch = saleEndEpoch + 7 days;
    }

    /**
     * @dev Function that allows the owner to withdraw the USDC balance.
     */
    function withdrawUsdc() external onlyOwner afterSale {
        require(
            usdcToken.transfer(owner(), usdcToken.balanceOf(address(this))),
            "Transfer failed"
        );
    }

    /**
     * @dev Function that returns the amount of USDC raised.
     */
    function getUsdcRaised() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }
}
