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

  const ownerAddress = accounts[0];
  const testAddress = accounts[1];
  const testAddress2 = accounts[2];

  const gasAmount = 6721975;

  it("function() : accepts ether and buys correct TTT from TTTTokenSell", async() => {
    const token = await tttToken.new({from: ownerAddress});
    const tokenSell = await tttTokenSell.new(token.address, {from: ownerAddress});

    var fbal = await token.balanceOf(testAddress);
    var bal = fromBigNumberWeiToEth(fbal);
    assert.equal(bal, 0, "The balance was not 0 - " + bal);

    await token.setTokenSaleAddress(tokenSell.address);

    var currentBlockTime = await getTimestampOfCurrentBlock();
    var startsAt = currentBlockTime + 1000;
    var endsAt = startsAt + 1000000;

    await tokenSell.startPhase(0, startsAt, endsAt, {address: ownerAddress, gas: gasAmount});
    await addSeconds(10000);
    await tokenSell.addAddressToWhitelist(testAddress);
    await tokenSell.addAddressToWhitelist(testAddress2);
    await tokenSell.sendTransaction({value: web3.toWei("50", "Ether"), from: testAddress, gas: gasAmount});

    fbal = await token.balanceOf(testAddress);
    bal = fromBigNumberWeiToEth(fbal);
    assert.equal(bal, 650000, "The balance was not 650000 - " + bal);

    await tokenSell.buyTokens(testAddress2, {value: web3.toWei("50", "Ether")});

    fbal = await token.balanceOf(testAddress2);
    bal = fromBigNumberWeiToEth(fbal);
    assert.equal(bal, 650000, "The balance was not 650000 - " + bal);

    await tokenSell.finalizePhase();

  });

});
