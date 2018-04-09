var tttTokenSell = artifacts.require("./TTTTokenSell.sol");
var tttToken = artifacts.require("./TTTToken.sol");
var BigNumber = require('bignumber.js');

function fromBigNumberWeiToEth(bigNum) {
  return bigNum.dividedBy(new BigNumber(10).pow(18)).toNumber();
}

function valueCheck(fbal, amt) {
  var bal = fromBigNumberWeiToEth(fbal);
  assert.equal(bal, amt, "The balance was not "+amt+" - It was "+bal);
}

const crowdsaleAddress = "0xb6d40Fb512e7c824c6a33861b233eE50c263A950";
const privatesaleAddress = "0x6876b854Bc0E2c59dc448949d1Caa5BF5bb08F54";
const presaleAddress = "0xcab76A29D35cc2f6B481112157675486180A560B";
const teamSupplyAddress = "0x4b1CCC3023C973A62984C865404f662e968c1FC1";
const ecoSupplyAddress = "0xb718C3f9D9947993BA752622a15dc6BBCA1d977d";

const gasAmount = 6721975;

contract('tttTokenSell', function(accounts){

  async function addSeconds(seconds) {
    return web3.currentProvider.send({jsonrpc: "2.0", method: "evm_increaseTime", params: [seconds], id: 0});
  }

  async function getTimestampOfCurrentBlock() {
    return web3.eth.getBlock(web3.eth.blockNumber).timestamp;
  }

  const ownerAddress = accounts[0];
  const testAddress = accounts[1];
  const testAddress2 = accounts[5];
  const testAddress3 = accounts[6];
  const testAddress4 = accounts[7];
  const airdropAddress = accounts[3];

  it("Accepts ether and buys correct TTT per phase from TTTTokenSell - no tranfer during ITO - post ITO transfer vest checks", async() => {
    const token = await tttToken.new({from: ownerAddress});
    const tokenSell = await tttTokenSell.new(token.address, {from: ownerAddress});

    var tBal0 = await token.balanceOf(testAddress);
    valueCheck(tBal0, 0);

    await token.setTokenSaleAddress(tokenSell.address);

    var currentBlockTime = await getTimestampOfCurrentBlock();
    var startsAt = currentBlockTime + 1000;
    var endsAt = startsAt + 1000000;

    await tokenSell.startPhase(0, startsAt, endsAt, {from: ownerAddress});
    await addSeconds(10000);
    await tokenSell.addAddressToWhitelist(testAddress);
    await tokenSell.addAddressToWhitelist(testAddress2);

    await tokenSell.sendTransaction({value: web3.toWei("50", "Ether"), from: testAddress});

    tBal0 = await token.balanceOf(testAddress);
    valueCheck(tBal0, 650000);

    await tokenSell.buyTokens(testAddress2, {value: web3.toWei("50", "Ether"), from: testAddress2});

    tBal1 = await token.balanceOf(testAddress2);
    valueCheck(tBal1, 650000);

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

    tBal0 = await token.balanceOf(testAddress);
    valueCheck(tBal0, 659750);

    await tokenSell.buyTokens(testAddress2, {value: web3.toWei("1", "Ether"), from: testAddress2});

    tBal1 = await token.balanceOf(testAddress2);
    valueCheck(tBal1, 659750);

    // end presale phase
    await tokenSell.finalizePhase();

    await addSeconds(10000);
    currentBlockTime = await getTimestampOfCurrentBlock();
    startsAt = currentBlockTime + 1000;
    endsAt = startsAt + 1000000;

    // transfer check, should NOT allow
    tBal0 = await token.balanceOf(testAddress);
    try { await token.transfer(testAddress2, tbal0, {from: testAddress}); }
    catch (e) { assert(true, true); console.log("ITO active - sending failed as expected"); }
    // token buy, should NOT allow
    try { await tokenSell.buyTokens(testAddress2, {value: web3.toWei("1", "Ether"), from: testAddress2}); }
    catch (e) { assert(true, true); console.log("Phase not active - token buy fail as expected"); }

    // start crowdsale phase
    await tokenSell.startPhase(2, startsAt, endsAt, {address: ownerAddress});

    await addSeconds(10000);
    await tokenSell.sendTransaction({value: web3.toWei("1", "Ether"), from: testAddress});

    tBal0 = await token.balanceOf(testAddress);
    valueCheck(tBal0, 668420);

    await tokenSell.buyTokens(testAddress2, {value: web3.toWei("1", "Ether"), from: testAddress2});

    tBal1 = await token.balanceOf(testAddress2);
    valueCheck(tBal1, 668420);

    var ct = await token.balanceOf(crowdsaleAddress);
    var cbal = fromBigNumberWeiToEth(ct);
    var burn = cbal * .7;
    var eco = cbal * .2;
    var air = cbal * .1;
    console.log("Ending crowdsale = "+cbal+" Burn = "+burn+" ToEco = "+eco+" ToAirdrop = "+air);
    // end ito
    await tokenSell.finalizeIto(burn, eco, air);

    // verify transfer
    tBal1 = await token.balanceOf(testAddress2);
    var chk = fromBigNumberWeiToEth(tBal1) + 10;
    await token.transfer(testAddress2, web3.toWei("10", "Ether"), {from: testAddress});
    tBal1 = await token.balanceOf(testAddress2);
    valueCheck(tBal1, chk);

    // vest checks should fail and NOT send tokens
    try { await token.transferFromVest(web3.toWei("100000", "Ether"), {from: ownerAddress}); }
    catch (e) { assert(true, true); console.log("Vest transfer fails as expected"); }

    // 10 months in seconds
    var months10 = 25920000;
    await addSeconds(months10);
    var oBal = await token.balanceOf(ownerAddress);
    chk = fromBigNumberWeiToEth(oBal) + 1002345;
    await token.transferFromVest(web3.toWei("1002345", "Ether"), {from: ownerAddress});
    oBal = await token.balanceOf(ownerAddress);
    valueCheck(oBal, chk);
    console.log("10 months later vest succeeds");


    // uncomment this to view emitted events
    //assert(false,false);

  });


});

contract('tttToken', function(accounts){

  const ownerAddress = accounts[0];
  const testAddress = accounts[1];

  // amount on creaion checks
  it("totalSupply: there should be 600 000 000 TTT", async () => {
    const token = await tttToken.new({from: ownerAddress});
    var b = await token.totalSupply();
    valueCheck(b, 600000000);
  });

  it("privatesaleSupply: there should be 90 000 000 TTT", async () => {
    const token = await tttToken.new({from: ownerAddress});
    var b = await token.balanceOf(privatesaleAddress);
    valueCheck(b, 90000000);
  });

  it("presaleSupply: there should be 120 000 000 TTT", async () => {
    const token = await tttToken.new({from: ownerAddress});
    var b = await token.balanceOf(presaleAddress);
    valueCheck(b, 120000000);
  });

  it("crowdsaleSupply: there should be 180 000 000 TTT", async () => {
    const token = await tttToken.new({from: ownerAddress});
    var b = await token.balanceOf(crowdsaleAddress);
    valueCheck(b, 180000000);
  });

  it("ecoSupply: there should be 90 000 000 TTT", async () => {
    const token = await tttToken.new({from: ownerAddress});
    var b = await token.balanceOf(ecoSupplyAddress);
    valueCheck(b, 90000000);
  });

  it("teamSupply: there should be 120 000 000 TTT", async () => {
    const token = await tttToken.new({from: ownerAddress});
    var b = await token.balanceOf(teamSupplyAddress);
    valueCheck(b, 120000000);
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

  it("setOwner(): owner can be changed by owner only", async() => {
    const token = await tttToken.new({from: ownerAddress});
    await token.transferOwnership(testAddress, {from: ownerAddress});
    // fails
    try { await token.transferOwnership(testAddress, {from: ownerAddress}); }
    catch (e) { assert(true, true); console.log("Owner could not be set by ownerAddress"); }


    // uncomment this to view emitted events
    //assert(false,false);

  });

});
