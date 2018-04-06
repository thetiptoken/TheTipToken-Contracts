var ttt = artifacts.require("./TTTToken.sol");
var tokenSell = artifacts.require("./TTTTokenSell.sol");

module.exports = function(deployer) {
  deployer.deploy(ttt).then(function() {
	  return deployer.deploy(tokenSell, ttt.address);
  }).then(function() {
	  return ttt.deployed().then(function(instance) {
		  instance.setTokenSaleAddress(tokenSell.address);
	  });
  }).catch(function(e){
	  console.error(e);
  });
};
