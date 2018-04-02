pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import "zeppelin-solidity/contracts/ownership/Whitelist.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./TTTToken.sol";

contract TTTTokenSell is Whitelist, Pausable {
	using SafeMath for uint;
	
	// TTTToken contract address
	address public tokenAddress;
	address public wallet;
	address public privatesaleAddress;
	address public presaleAddress;
	address public crowdsaleAddress;
	
	// Amount of wei currently raised
	uint256 public weiRaised;
	
	// Variables for phase start/end
	uint256 public startsAt;
	uint256 public endsAt;
	
	enum CurrentPhase { Privatesale, Presale, Crowdsale }
	
	CurrentPhase currentPhase;
	uint public currentPhaseRate;	
	
	TTTToken public token;
	
	// Emitted at the end of each phase
	event AmountRaised(address beneficiary, uint amountRaised);
	// Emitted on token purchase
	event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);
	
	modifier tokenPhaseIsActive() {
		assert(now >= startsAt && now <= endsAt);
		_;
	}
	
	function TTTTokenSell(address _tokenAddress) {
		wallet = 0xea2d2c0223af6e9c83db343aef2194564b27ee87;
		// start sell at private sell
		currentPhase = CurrentPhase.Privatesale;
		privatesaleAddress = 0x6876b854Bc0E2c59dc448949d1Caa5BF5bb08F54;
		presaleAddress = 0xcab76A29D35cc2f6B481112157675486180A560B;
		crowdsaleAddress = 0xb6d40Fb512e7c824c6a33861b233eE50c263A950;
		tokenAddress = _tokenAddress;
	}
	
	function startPhase(uint _phase, uint256 _startsAt, uint256 _endsAt) external onlyOwner {
		require(_phase >= 0 && _phase <= 2);
		require(_startsAt > endsAt && _endsAt > _startsAt);
		currentPhase = CurrentPhase(_phase);
		currentPhaseRate = getPhaseRate();
		assert(currentPhaseRate > 0);
		startsAt = _startsAt;
		endsAt = _endsAt;
	}
	
	function buyTokens(address _to) tokenPhaseIsActive onlyWhitelisted whenNotPaused payable {
		require(_to != 0x0);
		require(msg.value > 0);
		address from = getPhaseAddress();
		assert(from != 0x0);
		uint256 weiAmount = msg.value;
		uint256 tokens = weiAmount * currentPhaseRate;
		weiRaised = weiRaised.add(weiAmount);
		wallet.transfer(weiAmount);
		token.transferFromTokenSell(_to, from, tokens);
	}
	
	// To contribute, send a value transaction to the token sell Address.
    // Please include at least 100 000 gas.
    function () payable {
        buyTokens(msg.sender);
	}
	
	function getPhaseAddress() internal returns (address phase) {
		if(currentPhase == CurrentPhase.Privatesale)
			return privatesaleAddress;
		else if(currentPhase == CurrentPhase.Presale)
			return presaleAddress;
		else if(currentPhase == CurrentPhase.Crowdsale)
			return crowdsaleAddress;
		return 0x0;
	}
	
	// Amount of TTT per 1 ether. Will be updated closed to deployment
	function getPhaseRate() internal returns (uint rate) {
		if(currentPhase == CurrentPhase.Privatesale)
			return 13000;
		else if(currentPhase == CurrentPhase.Presale)
			return 9750;
		else if(currentPhase == CurrentPhase.Crowdsale)
			return 8670;
		return 0;
	}
}