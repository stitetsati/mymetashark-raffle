import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { FTM_TEST_CHAIN_ID, GOERLI_CHAIN_ID, MAINNET_CHAIN_ID, OPTIMISM_CHAIN_ID } from "./chainIds";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer, mymetashark, linkToken, vrfV2Wrapper } = await getNamedAccounts();
  const gasLimit = 200000;
  let params = [mymetashark, linkToken, vrfV2Wrapper, gasLimit];
  let raffle = await deploy(`MyMetaSharkRaffle`, {
    from: deployer,
    args: params,
    log: true,
    contract: "MyMetaSharkRaffle",
  });
  await hre.run("verify:verify", {
    address: raffle.address,
    constructorArguments: params,
  });
};
export default func;
func.tags = ["raffle"];
