var tttTokenSell = artifacts.require("./TTTTokenSell.sol");
var tttToken = artifacts.require("./TTTToken.sol");
var BigNumber = require('bignumber.js');

contract('tttTokenSell', function(accounts){

  function fromBigNumberWeiToEth(bigNum) {
    return bigNum.dividedBy(new BigNumber(10).pow(18)).toNumber();
  }

  async function addSeconds(seconds) {
    return web3.currentProvider.send({jsonrpc: "2.0", method: "evm_increaseTime", params: [seconds], id: 0});
  }

  async function getTimestampOfCurrentBlock() {
    return web3.eth.getBlock(web3.eth.blockNumber).timestamp;
  }

  async function valueCheck(fbal, amt) {
    var bal = fromBigNumberWeiToEth(fbal);
    assert.equal(bal, amt, "The balance was not "+amt+" - It was "+bal);
  }

  const ownerAddress = accounts[0];
  const testAddress = accounts[1];
  const testAddress2 = accounts[5];
  const failAddress = accounts[3];
  const crowdsaleAddress = "0xb6d40Fb512e7c824c6a33861b233eE50c263A950";

  const gasAmount = 6721975;


  it("Accepts ether and buys correct TTT per phase from TTTTokenSell", async() => {
    const token = await tttToken.new({from: ownerAddress});
    const tokenSell = await tttTokenSell.new(token.address, {from: ownerAddress});

    var fbal = await token.balanceOf(testAddress);
    valueCheck(fbal, 0);

    await token.setTokenSaleAddress(tokenSell.address);

    var currentBlockTime = await getTimestampOfCurrentBlock();
    var startsAt = currentBlockTime + 1000;
    var endsAt = startsAt + 1000000;

    await tokenSell.startPhase(0, startsAt, endsAt, {from: ownerAddress});
    await addSeconds(10000);
    await tokenSell.addAddressToWhitelist(testAddress);
    await tokenSell.addAddressToWhitelist(testAddress2);

    await tokenSell.sendTransaction({value: web3.toWei("50", "Ether"), from: testAddress});

    fbal = await token.balanceOf(testAddress);
    valueCheck(fbal, 650000);

    await tokenSell.buyTokens(testAddress2, {value: web3.toWei("50", "Ether"), from: testAddress2});

    fbal = await token.balanceOf(testAddress2);
    valueCheck(fbal, 650000);

    // end Privatesale phase
    await tokenSell.finalizePhase();

    await addSeconds(10000);
    currentBlockTime = await getTimestampOfCurrentBlock();
    startsAt = currentBlockTime + 1000;
    endsAt = startsAt + 1000000;

    // start presale phase
    await tokenSell.startPhase(1, startsAt, endsAt, {address: ownerAddress});

    await addSeconds(10000);
    await tokenSell.sendTransaction({value: web3.toWei("1", "Ether"), from: testAddress});

    fbal = await token.balanceOf(testAddress);
    valueCheck(fbal, 659750);

    await tokenSell.buyTokens(testAddress2, {value: web3.toWei("1", "Ether"), from: testAddress2});

    fbal = await token.balanceOf(testAddress2);
    valueCheck(fbal, 659750);

    // end presale phase
    await tokenSell.finalizePhase();

    await addSeconds(10000);
    currentBlockTime = await getTimestampOfCurrentBlock();
    startsAt = currentBlockTime + 1000;
    endsAt = startsAt + 1000000;

    // start crowdsale phase
    await tokenSell.startPhase(2, startsAt, endsAt, {address: ownerAddress});

    await addSeconds(10000);
    await tokenSell.sendTransaction({value: web3.toWei("1", "Ether"), from: testAddress});

    fbal = await token.balanceOf(testAddress);
    valueCheck(fbal, 668420);

    await tokenSell.buyTokens(testAddress2, {value: web3.toWei("1", "Ether"), from: testAddress2});

    fbal = await token.balanceOf(testAddress2);
    valueCheck(fbal, 668420);

    fbal = await token.balanceOf(crowdsaleAddress);
    var cbal = fromBigNumberWeiToEth(fbal);
    var burn = cbal * .7;
    var eco = cbal * .2;
    var air = cbal * .1;
    console.log("Ending crowdsale = "+cbal+" Burn = "+burn+" ToEco = "+eco+" ToAirdrop = "+air);
    // end ito
    tokenSell.finalizeIto(burn, eco, air);

    // verify transfer
    tbal = await token.balanceOf(testAddress);
    var tbal1 = await token.balanceOf(testAddress2);
    var chk = tbal + tbal1;
    await token.transfer(testAddress2, tbal, {from: testAddress});
    fbal = await token.balanceOf(testAddress);
    cbal = await token.balanceOf(testAddress2);
    valueCheck(fbal, 0);
    valueCheck(cbal, chk);

  });

  it("setTokenSaleAddress(): it should NOT let anyone but the owner set the tokenSale address", function(done) {
    tttToken.new({from: ownerAddress, gas: gasAmount})
    .then(function(instance) {
      return instance.setTokenSaleAddress(accounts[5], {from: accounts[5]});
    }).catch(() => {
      assert(true, true);
      done();
    });
  });


});
