import { HardhatUserConfig } from "hardhat/config";
import "@matterlabs/hardhat-zksync";
import "@matterlabs/hardhat-zksync-verify";




const config: HardhatUserConfig = {
  zksolc: {
    version: "1.5.11", // Ensure version is 1.5.7!
    settings: {
      enableEraVMExtensions: true,
    },
  },
  defaultNetwork: "abstractTestnet",
  networks: {
    abstractTestnet: {
      url: "https://api.testnet.abs.xyz",
      ethNetwork: "sepolia",
      zksync: true,
      chainId: 11124,
    },
    abstractMainnet: {
      url: "https://api.mainnet.abs.xyz",
      ethNetwork: "mainnet",
      zksync: true,
      chainId: 2741,
    },
  },
  etherscan: {
    apiKey: {
      abstractTestnet: "TACK2D1RGYX9U7MC31SZWWQ7FCWRYQ96AD",
      abstractMainnet: "IEYKU3EEM5XCD76N7Y7HF9HG7M9ARZ2H4A",
    },
    customChains: [
      {
        network: "abstractTestnet",
        chainId: 11124,
        urls: {
          apiURL: "https://api-sepolia.abscan.org/api",
          browserURL: "https://sepolia.abscan.org/",
        },
      },
      {
        network: "abstractMainnet",
        chainId: 2741,
        urls: {
          apiURL: "https://api.abscan.org/api",
          browserURL: "https://abscan.org/",
        },
      },
    ],
  },
  solidity: {
    version: "0.8.28",
  },
};

export default config;
