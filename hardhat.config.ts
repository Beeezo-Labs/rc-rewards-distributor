import { HardhatUserConfig } from 'hardhat/config';
import '@openzeppelin/hardhat-upgrades';
import '@nomicfoundation/hardhat-toolbox';
import "solidity-docgen";

const config: HardhatUserConfig = {
  solidity: '0.8.24',
  gasReporter: {
    enabled: false,
  },
  docgen: {
    outputDir: "./docs",
    pages: "files",
    exclude: ["mocks", "interfaces"],
  },
};

export default config;
