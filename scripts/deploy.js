const hre = require("hardhat");
async function main() {
  const BountyFactory = await hre.ethers.getContractFactory("VortexLiquidityBounty");
  const bountyPool = await BountyFactory.deploy();
  await bountyPool.deployed();
  console.log("-> Vortex Liquidity Bounty initialized at:", bountyPool.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
