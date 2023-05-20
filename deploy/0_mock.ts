import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { FTM_TEST_CHAIN_ID, GOERLI_CHAIN_ID, MAINNET_CHAIN_ID, OPTIMISM_CHAIN_ID } from "./chainIds";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  let nft = await deploy(`NFT`, {
    from: deployer,
    log: true,
    contract: "NFT",
  });
  await hre.run("verify:verify", {
    address: nft.address,
  });
};
export default func;
func.tags = ["nft"];
