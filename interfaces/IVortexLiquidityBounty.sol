// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IVortexLiquidityBounty {
    function stakeLiquidity(uint256 amount) external payable;
    function harvestBounty() external returns (uint256);
    function withdrawLiquidity(uint256 amount) external;
}
