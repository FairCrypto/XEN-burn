// SPDX-License-Identifier: MIT

const assert = require('assert');
const timeMachine = require('ganache-time-traveler');
const {toBigInt} = require("../src/utils");

const XENCrypto = artifacts.require("XENCrypto");
const XENBurn = artifacts.require("XENBurn");

require('dotenv').config();

const extraPrint = process.env.EXTRA_PRINT;

const ether = 10n ** 18n;

const assertAttribute = (attributes = []) => (name, value) => {
    const attr = attributes.find(a => a.trait_type === name);
    assert.ok(attr);
    if (value) {
        assert.ok(attr.value === value);
    }
}

contract("XEN Burn", async accounts => {

    let token;
    let xenBurn;
    let xenCryptoAddress;

    let xenBalance;
    let tokenId;

    const t0days = 100;
    const amount = 1_000n * ether;
    const expectedXENBalance = 330_000n * ether;
    // const provider = new Web3Provider(web3.currentProvider);

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            xenBurn = await XENBurn.deployed();

            xenCryptoAddress = token.address;
        } catch (e) {
            console.error(e)
        }
    })

    it("Should read XENFT symbol and name", async () => {
        assert.ok(await xenBurn.name() === 'XEN Burn');
        assert.ok(await xenBurn.symbol() === 'XENB');
    })

    it("Should read XEN Crypto Address params", async () => {
        assert.ok(await xenBurn.xenCrypto() === xenCryptoAddress)
    })

    it("Should verify that XEN Crypto has initial Global Rank === 1", async () => {
        const expectedInitialGlobalRank = 1;
        assert.ok(await token.globalRank().then(_ => _.toNumber()) === expectedInitialGlobalRank);
        const expectedCurrentMaxTerm = 100 * 24 * 3600;
        assert.ok(await token.getCurrentMaxTerm().then(_ => _.toNumber()) === expectedCurrentMaxTerm);
    })

    it("Should reject burn transaction with incorrect amount OR term", async () => {
        assert.rejects(() => xenBurn.burnXen(0, { from: accounts[0] }));
    })

    it("Should allow to obtain initial XEN balance via regular minting", async () => {
        await assert.doesNotReject(() => token.claimRank(t0days, { from: accounts[1] }));
        await timeMachine.advanceTime(t0days * 24 * 3600 + 3600);
        await timeMachine.advanceBlock();
        await assert.doesNotReject(() => token.claimMintReward({ from: accounts[1] }));
    });

    it("XEN Crypto user shall have positive XEN balance post claimMintReward", async () => {
        xenBalance = await token.balanceOf(accounts[1], { from: accounts[1] }).then(toBigInt);
        assert.ok(xenBalance === expectedXENBalance);
    });

    it("Should reject to perform burn operation without XEN approval", async () => {
        await assert.rejects(() => xenBurn.burnXen(amount, { from: accounts[1] }));
    })

    it("Should allow to perform burn operation with correct params and approval", async () => {
        assert.ok(xenBalance > amount)
        await assert.doesNotReject(() => token.approve(xenBurn.address, amount, { from: accounts[1] }));
        const res = await xenBurn.burnXen(amount, { from: accounts[1] });
        const { gasUsed } = res.receipt;
        //console.log(res.logs)
        tokenId  = res.logs[0].args[2].toNumber();
        parseInt(extraPrint || '0') > 0 && console.log('tokenId', tokenId, 'gas used', gasUsed);
        assert.ok(tokenId === 1);
        //assert.ok(BigInt(expectedAmount.toString()) === amount);
    })

    it("Should be able to return tokenURI as base-64 encoded data URL", async () => {
        const encodedStr = await xenBurn.tokenURI(tokenId)
        assert.ok(encodedStr.startsWith('data:application/json;base64,'));
        const base64str = encodedStr.replace('data:application/json;base64,', '');
        const decodedStr = Buffer.from(base64str, 'base64').toString('utf8');
        extraPrint === '3' && console.log(decodedStr)
        const metadata = JSON.parse(decodedStr.replace(/\n/, ''));
        assert.ok('name' in metadata);
        assert.ok('description' in metadata);
        assert.ok('image' in metadata);
        assert.ok('attributes' in metadata);
        assert.ok(Array.isArray(metadata.attributes));
        assertAttribute(metadata.attributes)('Burned XEN', (amount / ether).toString());
        assert.ok(metadata.image.startsWith('data:image/svg+xml;base64,'));
        const imageBase64 = metadata.image.replace('data:image/svg+xml;base64,', '');
        const decodedImage = Buffer.from(imageBase64, 'base64').toString();
        assert.ok(decodedImage.startsWith('<svg'));
        assert.ok(decodedImage.endsWith('</svg>'));
        extraPrint === '2' && console.log(decodedImage);
    })

    it("Should allow to perform another burn operation with correct params and approval", async () => {
        const amount = 10_001n * ether;
        xenBalance = await token.balanceOf(accounts[1], { from: accounts[1] }).then(toBigInt);
        assert.ok(xenBalance > amount)
        await assert.doesNotReject(() => token.approve(xenBurn.address, amount, { from: accounts[1] }));
        const res = await xenBurn.burnXen(amount, { from: accounts[1] });
        const { gasUsed } = res.receipt;
        const newTokenId  = res.logs[0].args[2];

        parseInt(extraPrint || '0') > 0 && console.log('tokenId', newTokenId.toNumber(), 'gas used', gasUsed);
        assert.ok(newTokenId.toNumber() === tokenId + 1);
        // tokenId = newTokenId.toNumber();
    })

    it("Should be able to return tokenURI for another token as base-64 encoded data URL", async () => {
        const amount = 10_001n * ether;
        const encodedStr = await xenBurn.tokenURI(tokenId + 1)
        assert.ok(encodedStr.startsWith('data:application/json;base64,'));
        const base64str = encodedStr.replace('data:application/json;base64,', '');
        const decodedStr = Buffer.from(base64str, 'base64').toString('utf8');
        extraPrint === '3' && console.log(decodedStr)
        const metadata = JSON.parse(decodedStr.replace(/\n/, ''));
        assert.ok('name' in metadata);
        assert.ok('description' in metadata);
        assert.ok('image' in metadata);
        assert.ok('attributes' in metadata);
        assert.ok(Array.isArray(metadata.attributes));
        assertAttribute(metadata.attributes)('Burned XEN', (amount / ether).toString());
        assert.ok(metadata.image.startsWith('data:image/svg+xml;base64,'));
        const imageBase64 = metadata.image.replace('data:image/svg+xml;base64,', '');
        const decodedImage = Buffer.from(imageBase64, 'base64').toString();
        assert.ok(decodedImage.startsWith('<svg'));
        assert.ok(decodedImage.endsWith('</svg>'));
        extraPrint === '2' && console.log(decodedImage);
    })

    it("Should show correct token balance post XENFTs mints", async () => {
        const balance = await xenBurn.balanceOf(accounts[1], { from: accounts[1] }).then(_ => _.toNumber());
        assert.ok(balance === 2);
    })

    it("Should show correct token IDs owned by the user", async () => {
        const ownedTokens1 = await xenBurn.ownedTokens({ from: accounts[1] })
            .then(tokenIds => tokenIds.map(id => id.toNumber()));
        assert.ok(ownedTokens1.length === 2);
        assert.ok(ownedTokens1.includes(tokenId))
        assert.ok(ownedTokens1.includes(tokenId + 1))
    })

    it("Should show NO token IDs owned by the non-user", async () => {
        const ownedTokens0 = await xenBurn.ownedTokens({ from: accounts[0] })
            .then(tokenIds => tokenIds.map(id => id.toNumber()));
        assert.ok(ownedTokens0.length === 0);
    })

    it("Should reject XENFT transfer by a non-owner and no approval", async () => {
        await assert.rejects(
            () => xenBurn.transferFrom(accounts[2], accounts[3], tokenId + 1),
            'ERC721: transfer from incorrect owner'
        );
    })

    it("Should allow XENFT transfer by an owner", async () => {
        await assert.doesNotReject(
            () => xenBurn.transferFrom(accounts[1], accounts[3], tokenId + 1, { from: accounts[1] })
        );
    })

    it("Should show correct token balances post-transfer", async () => {
        const ownedTokens1 = await xenBurn.ownedTokens({ from: accounts[1] })
          .then(tokenIds => tokenIds.map(id => id.toNumber()));
        assert.ok(ownedTokens1.length === 1);
        const ownedTokens3 = await xenBurn.ownedTokens({ from: accounts[3] })
          .then(tokenIds => tokenIds.map(id => id.toNumber()));
        assert.ok(ownedTokens3.length === 1);
    })

})
