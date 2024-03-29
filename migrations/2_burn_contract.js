const XENBurn = artifacts.require("XENBurn");
const XENCrypto = artifacts.require("XENCrypto");
const MagicNumbers = artifacts.require("MagicNumbers");

const DateTime = artifacts.require("DateTime");
const BurnInfo = artifacts.require("BurnInfo");
const BurnMetadata = artifacts.require("BurnMetadata");

require("dotenv").config();

module.exports = async function (deployer, network) {

    const xenContractAddress = process.env[`${network.toUpperCase()}_CONTRACT_ADDRESS`];

    await deployer.deploy(DateTime);
    await deployer.link(DateTime, BurnMetadata);

    await deployer.deploy(BurnInfo);
    await deployer.link(BurnInfo, BurnMetadata);
    await deployer.link(BurnInfo, XENBurn);

    await deployer.deploy(BurnMetadata);
    await deployer.link(BurnMetadata, XENBurn);

    await deployer.deploy(MagicNumbers);
    await deployer.link(MagicNumbers, XENBurn);

    const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
    const forwarder = process.env[`${network.toUpperCase()}_FORWARDER`] || ZERO_ADDRESS;
    const royaltyReceiver = process.env[`${network.toUpperCase()}_ROYALTY_RECEIVER`] || ZERO_ADDRESS;

    console.log('    forwarder:', forwarder);
    console.log('    royalty receiver:', royaltyReceiver);

    if (xenContractAddress) {
        await deployer.deploy(
            XENBurn,
            xenContractAddress,
            forwarder,
            royaltyReceiver
        );
    } else {
        const xenContract = await XENCrypto.deployed();
        // console.log(network, xenContract?.address)
        await deployer.deploy(
            XENBurn,
            xenContract.address,
            forwarder,
            royaltyReceiver
        );
    }
};
