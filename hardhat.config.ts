import * as dotenv from "dotenv";
import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "hardhat-deploy";

dotenv.config();

const config: HardhatUserConfig = {
  namedAccounts: {
    deployer: {
      default: 0,
    },
    mymetashark: {
      mainnet: "0x812Ae1DB094658177582A96b8dd970870165Fe80",
      goerli: "0xB89eFb9D4E0019af9F07377E51a125865Da6c149",
    },
    linkToken: {
      mainnet: "0x514910771AF9Ca656af840dff83E8264EcF986CA",
      goerli: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
    },
    vrfV2Wrapper: {
      mainnet: "0x5A861794B927983406fCE1D062e00b9368d97Df6",
      goerli: "0x708701a1DfF4f478de54383E49a627eD4852C816",
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      // forking: {
      // url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      // url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      // blockNumber: 28919813, // for stable mainnet fork test
      // },
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.TEST_PRIVATE_KEY}`],
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.MAINNET_PRIVATE_KEY}`],
    },
    ftmTestnet: {
      url: `https://rpc.ankr.com/fantom_testnet`,
      accounts: [`${process.env.TEST_PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: `${process.env.ETHERSCAN_API_KEY}`,
      goerli: `${process.env.ETHERSCAN_API_KEY}`,
    },
  },
};

export default config;
