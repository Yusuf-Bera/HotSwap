// deploy/00_deploy_your_contract.js

const { ethers } = require("hardhat");

const localChainId = "31337";

// const sleep = (ms) =>
//   new Promise((r) =>
//     setTimeout(() => {
//       console.log(`waited for ${(ms / 1000).toFixed(3)} seconds`);
//       r();
//     }, ms)
//   );

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  await deploy("Balloons", {
    from: deployer,
    // args: [ "Hello", ethers.utils.parseEther("1.5") ],
    log: true,
  });

  const balloons = await ethers.getContract("Balloons", deployer);

  await deploy("DEX", {
    from: deployer,
    args: [balloons.address],
    log: true,
    //waitConfirmations: 5,
  });

  // uniswap router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
  // aave protocol : 0x7d2768de32b0b80b7a3454c06bdac94a69ddc7a9
  // await deploy("MarginTrande", {
  //   from: deployer,
  //   args: [
  //     "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
  //     "0x7d2768de32b0b80b7a3454c06bdac94a69ddc7a9",
  //   ],
  // });

  const dex = await ethers.getContract("DEX", deployer);

  // paste in your front-end address here to get 10 balloons on deploy:
  await balloons.transfer(
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "" + 10 * 10 ** 18
  );

  // uncomment to init DEX on deploy:
  console.log(
    "Approving DEX (" + dex.address + ") to take Balloons from main account..."
  );
  // If you are going to the testnet make sure your deployer account has enough ETH
  await balloons.approve(dex.address, ethers.utils.parseEther("100"));
  console.log("INIT exchange...");
  await dex.init(ethers.utils.parseEther("5"), {
    value: ethers.utils.parseEther("5"),
    gasLimit: 200000,
  });
};
module.exports.tags = ["Balloons", "DEX"];
