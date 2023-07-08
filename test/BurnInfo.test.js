const {toBigInt} = require("../src/utils");
const assert = require("assert");
const BurnInfo = artifacts.require("BurnInfo");

const extraPrint = process.env.EXTRA_PRINT;

let burnInfo
const r = 0b1000_0000;
const l = 0b0100_0000;

// const maxUint8 = 2n ** 8n - 1n;
const maxUint16 = 2n ** 16n - 1n;
const maxUint64 = 2n ** 64n - 1n;
const maxUint128 = 2n ** 128n - 1n;
const maxUint256 = 2n ** 256n - 1n;

/*
//      term (uint16)
//      | maturityTs (uint64)
//      | amount (uint128)
//      | apy (uint16)
//      | rarityScore (uint16)
//      | rarityBits (uint16):
//          [15] tokenIdIsPrime
//          [14] tokenIdIsFib
//          [14] blockIdIsPrime
//          [13] blockIdIsFib
//          [0-13] ...
 */
contract("BurnInfo Library", async () => {

    before(async () => {
        try {
            burnInfo = await BurnInfo.deployed();
        } catch (e) {
            console.error(e)
        }
    });

    it("Should perform RarityBits encoding/decoding", async () => {
        const testInfo = [
            { isPrime: false, isFib: false, blockIsPrime: false, blockIsFib: false },
            { isPrime: false, isFib: false, blockIsPrime: false, blockIsFib: true },
            { isPrime: false, isFib: false, blockIsPrime: true, blockIsFib: false },
            { isPrime: false, isFib: false, blockIsPrime: true, blockIsFib: true },
            { isPrime: false, isFib: true, blockIsPrime: false, blockIsFib: false },
            { isPrime: false, isFib: true, blockIsPrime: false, blockIsFib: true },
            { isPrime: false, isFib: true, blockIsPrime: true, blockIsFib: false },
            { isPrime: false, isFib: true, blockIsPrime: true, blockIsFib: true },
            { isPrime: true, isFib: false, blockIsPrime: false, blockIsFib: false },
            { isPrime: true, isFib: false, blockIsPrime: false, blockIsFib: true },
            { isPrime: true, isFib: false, blockIsPrime: true, blockIsFib: false },
            { isPrime: true, isFib: false, blockIsPrime: true, blockIsFib: true },
            { isPrime: true, isFib: true, blockIsPrime: false, blockIsFib: false },
            { isPrime: true, isFib: true, blockIsPrime: false, blockIsFib: true },
            { isPrime: true, isFib: true, blockIsPrime: true, blockIsFib: false },
            { isPrime: true, isFib: true, blockIsPrime: true, blockIsFib: true },
        ]

        for(const test of testInfo) {
            const { isPrime, isFib, blockIsPrime, blockIsFib } = test;
            const rarityBitsEncoded = await burnInfo.encodeRarityBits(isPrime, isFib, blockIsPrime, blockIsFib);
            parseInt(extraPrint || '0') > 2 && console.log(BigInt(rarityBitsEncoded).toString(2).padStart(16, '0'))
            const rarityBitsDecoded = await burnInfo.decodeRarityBits(rarityBitsEncoded);
            assert.ok(rarityBitsDecoded.isPrime === test.isPrime);
            assert.ok(rarityBitsDecoded.isFib === test.isFib);
            assert.ok(rarityBitsDecoded.blockIsPrime === test.blockIsPrime);
            assert.ok(rarityBitsDecoded.blockIsFib === test.blockIsFib);
        }
    });

    it("Should perform BurnInfo encoding/decoding", async () => {
        const _burnTs = 2;
        const _amount = 3;
        const _rarityScore = 5;
        const _rarityBits = 6;
        const encodedBurnInfo =
            await burnInfo.encodeBurnInfo(_burnTs, _amount, _rarityScore, _rarityBits)
                .then(toBigInt);
        parseInt(extraPrint || '0') > 2 && console.log(BigInt(encodedBurnInfo).toString(2).padStart(256, '0'))
        const { burnTs, amount, rarityScore, rarityBits } =
            await burnInfo.decodeBurnInfo(encodedBurnInfo);
        assert.ok(burnTs.toNumber() === _burnTs, `bad burnTs ${burnTs.toNumber()}`);
        assert.ok(amount.toNumber() === _amount, `bad amount ${amount.toNumber()}`);
        assert.ok(rarityScore.toNumber() === _rarityScore, `bad rarityScore ${rarityScore.toNumber()}`);
        assert.ok(rarityBits.toNumber() === _rarityBits, `bad rarityBits ${rarityBits.toNumber()}`);
    })

    it("Should encode correctly in overflow conditions (burnTs)", async () => {
        const _burnTs = maxUint256;
        const _amount = 3;
        const _rarityScore = 5;
        const _rarityBits = 6;
        const encodedBurnInfo =
            await burnInfo.encodeBurnInfo(_burnTs, _amount, _rarityScore, _rarityBits)
                .then(toBigInt);
        parseInt(extraPrint || '0') > 2 && console.log(BigInt(encodedBurnInfo).toString(2).padStart(256, '0'))
        const { burnTs, amount } = await burnInfo.decodeBurnInfo(encodedBurnInfo);

        assert.ok(toBigInt(burnTs) === maxUint64, `bad burnTs ${toBigInt(burnTs)}`);
        assert.ok(amount.toNumber() === _amount, `bad amount ${amount.toNumber()}`);
    });

    it("Should encode correctly in overflow conditions (amount)", async () => {
        const _burnTs = 2;
        const _amount = maxUint256;
        const _rarityScore = 5;
        const _rarityBits = 6;
        const encodedBurnInfo =
          await burnInfo.encodeBurnInfo(_burnTs, _amount, _rarityScore, _rarityBits)
            .then(toBigInt);
        parseInt(extraPrint || '0') > 2 && console.log(BigInt(encodedBurnInfo).toString(2).padStart(256, '0'))
        const { burnTs, amount, apy } = await await burnInfo.decodeBurnInfo(encodedBurnInfo);

        assert.ok(burnTs.toNumber() === _burnTs, `bad burnTs ${burnTs.toNumber()}`);
        assert.ok(toBigInt(amount) === maxUint128, `bad amount ${toBigInt(amount)}`);
    });

    it("Should encode correctly in overflow conditions (rarityScore)", async () => {
        const _burnTs = 2;
        const _amount = 3;
        const _rarityScore = maxUint256;
        const _rarityBits = 6;
        const encodedBurnInfo =
          await burnInfo.encodeBurnInfo(_burnTs, _amount, _rarityScore, _rarityBits)
            .then(toBigInt);
        parseInt(extraPrint || '0') > 2 && console.log(BigInt(encodedBurnInfo).toString(2).padStart(256, '0'))
        const { burnTs, amount, rarityScore, rarityBits } = await burnInfo.decodeBurnInfo(encodedBurnInfo);

        assert.ok(burnTs.toNumber() === _burnTs, `bad burnTs ${burnTs.toNumber()}`);
        assert.ok( amount.toNumber() === _amount, `bad amount ${amount.toNumber()}`);
        assert.ok(toBigInt(rarityScore) === maxUint16, `bad rarityScore ${toBigInt(rarityScore)}`);
        assert.ok(rarityBits.toNumber() === _rarityBits, `bad rarityBits ${rarityBits.toNumber()}`);
    });

    it("Should encode correctly in overflow conditions (rarityBits)", async () => {
        const _burnTs = 2;
        const _amount = 3;
        const _rarityScore = 5;
        const _rarityBits = maxUint256;
        const encodedBurnInfo =
          await burnInfo.encodeBurnInfo(_burnTs, _amount, _rarityScore, _rarityBits)
            .then(toBigInt);
        parseInt(extraPrint || '0') > 2 && console.log(BigInt(encodedBurnInfo).toString(2).padStart(256, '0'))
        const { burnTs, amount, rarityScore, rarityBits } = await burnInfo.decodeBurnInfo(encodedBurnInfo);

        assert.ok(burnTs.toNumber() === _burnTs, `bad burnTs ${burnTs.toNumber()}`);
        assert.ok( amount.toNumber() === _amount, `bad amount ${amount.toNumber()}`);
        assert.ok(rarityScore.toNumber() === _rarityScore, `bad rarityScore ${rarityScore.toNumber()}`);
        assert.ok(toBigInt(rarityBits) === maxUint16, `bad rarityBits ${toBigInt(rarityBits)}`);
    });
})
