// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";

contract MarginTrader {
    IUniswapV2Router02 public uniswapRouter;
    ILendingPool public lendingPool;

    constructor(address _uniswapRouter, address _lendingPool) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        lendingPool = ILendingPool(_lendingPool);
    }

    function performMarginTrade(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _onBehalfOf,
        uint256 _leverage
    ) public {
        uint256 borrowAmount = _amountIn * _leverage;

        borrowFromAave(_tokenIn, borrowAmount, _onBehalfOf);

        // Approve the Uniswap router to transfer tokens for the swap
        IERC20(_tokenIn).approve(address(uniswapRouter), borrowAmount);

        // Perform the trade
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        uniswapRouter.swapExactTokensForTokens(
            borrowAmount,
            _amountOutMin,
            path,
            address(this),
            block.timestamp + 1800
        );

        uint256 amountToRepay = IERC20(_tokenIn).balanceOf(address(this));
        IERC20(_tokenIn).approve(address(lendingPool), amountToRepay);
        repayAave(_tokenIn, amountToRepay, _onBehalfOf);
    }

    function borrowFromAave(
        address _tokenIn,
        uint256 _amount,
        address _onBehalfOf
    ) internal {
        lendingPool.borrow(_tokenIn, _amount, 2, 0, _onBehalfOf);
    }

    function repayAave(
        address _tokenIn,
        uint256 _amount,
        address _onBehalfOf
    ) internal {
        lendingPool.repay(_tokenIn, _amount, 2, _onBehalfOf);
    }

    function closePosition(address _tokenIn, address _tokenOut) public {
        uint256 amountToRepay = calculateRepaymentAmount(_tokenIn);

        IERC20(_tokenOut).approve(
            address(uniswapRouter),
            IERC20(_tokenOut).balanceOf(address(this))
        );

        // Swap _tokenOut to _tokenIn
        address[] memory path = new address[](2);
        path[0] = _tokenOut;
        path[1] = _tokenIn;

        uniswapRouter.swapTokensForExactTokens(
            amountToRepay,
            IERC20(_tokenOut).balanceOf(address(this)),
            path,
            address(this),
            block.timestamp + 1800
        );

        // Now repay Aave
        IERC20(_tokenIn).approve(address(lendingPool), amountToRepay);
        repayAave(_tokenIn, amountToRepay, msg.sender);

        // Send any remaining tokens to the user
        // IERC20(_tokenIn).transfer(
            msg.sender,
            IERC20(_tokenIn).balanceOf(address(this))
        );
        IERC20(_tokenOut).transfer(
            msg.sender,
            IERC20(_tokenOut).balanceOf(address(this))
        );
    }

    function calculateRepaymentAmount(
        address _tokenIn,
        address _user
    ) public view returns (uint256) {
        (, uint256 totalDebtETH, , , ) = lendingPool.getUserAccountData(_user);
        return (totalDebtETH * getPriceETHUSD()) / getPriceTokenUSD(_tokenIn);
    }
}
