import { Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync";
import { vars } from "hardhat/config";

export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script`);

  // Initialize the wallet using your private key.
  const wallet = new Wallet(vars.get("DEPLOYER_PRIVATE_KEY"));

  // Create deployer object and load the contract artifact.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("HelloAbstract");

  // Define constructor arguments
  const tokenName = "Hello Abstract";
  const tokenSymbol = "HAB";
  const publicMintPrice = hre.ethers.parseEther("0.000001").toString();
  const allowlist01Price = hre.ethers.parseEther("0.000001").toString();
  const royaltyFee = 500; // 5% (500 basis points)
  const royaltyRecipient = wallet.address; // Use deployer's address as recipient

  // Deploy contract with arguments
  const tokenContract = await deployer.deploy(artifact, [
    tokenName,
    tokenSymbol,
    publicMintPrice,
    allowlist01Price,
    royaltyFee,
    royaltyRecipient
  ]);

  console.log(
    `${artifact.contractName} was deployed to ${await tokenContract.getAddress()}`
  );
}
