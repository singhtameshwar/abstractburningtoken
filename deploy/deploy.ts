import { Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync";
import { vars } from "hardhat/config";

export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script`);
  const wallet = new Wallet(vars.get("DEPLOYER_PRIVATE_KEY"));
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("HelloAbstract");

  const tokenName = "HelloAbstract";
  const tokenSymbol = "HAB";
  const publicMintPrice = hre.ethers.parseEther("0.0001").toString();
  const allowlist01Price = hre.ethers.parseEther("0.0001").toString();
  const royaltyFee = 500;
  const royaltyRecipient = wallet.address;



  const tokenContract = await deployer.deploy(
    artifact, 
    [
      tokenName,
      tokenSymbol,
      publicMintPrice,
      allowlist01Price,
      royaltyFee,
      royaltyRecipient
    ],
    undefined,
  );

  console.log(
    `${artifact.contractName} was deployed to ${await tokenContract.getAddress()}`
  );
}