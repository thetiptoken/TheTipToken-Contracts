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
	uint ethMin;
	uint ethMax;

	enum CurrentPhase { Privatesale, Presale, Crowdsale }

	CurrentPhase currentPhase;
	uint public currentPhaseRate;

	TTTToken public token;

	event AmountRaised(address beneficiary, uint amountRaised);
	event TokenPurchased(address indexed purchaser, uint256 value, uint256 amount);
	event TokenPhaseStarted(CurrentPhase phase, uint256 startsAt, uint256 endsAt);
	event TokenPhaseEnded(CurrentPhase phase);

	modifier tokenPhaseIsActive() {
		assert(now >= startsAt && now <= endsAt);
		_;
	}

	function TTTTokenSell(address _tokenAddress) {
		wallet = 0xea2d2c0223af6e9c83db343aef2194564b27ee87;

		privatesaleAddress = 0x6876b854Bc0E2c59dc448949d1Caa5BF5bb08F54;
		presaleAddress = 0xcab76A29D35cc2f6B481112157675486180A560B;
		crowdsaleAddress = 0xb6d40Fb512e7c824c6a33861b233eE50c263A950;

		tokenAddress = _tokenAddress;
		token = TTTToken(tokenAddress);

		startsAt = 0;
		endsAt = 0;
		ethMin = 0;
		ethMax = 10000 * 10**uint(18);
	}

	function startPhase(uint _phase, uint256 _startsAt, uint256 _endsAt) external onlyOwner {
		require(_phase >= 0 && _phase <= 2);
		require(_startsAt > endsAt && _endsAt > _startsAt);
		currentPhase = CurrentPhase(_phase);
		currentPhaseRate = getPhaseRate();
		assert(currentPhaseRate > 0);
		if(currentPhase == CurrentPhase.Privatesale) ethMin = 50 * 10**uint(18);
		else {
			ethMin = 0;
			ethMax = 15 * 10**uint(18);
		}
		startsAt = _startsAt;
		endsAt = _endsAt;
		TokenPhaseStarted(currentPhase, startsAt, endsAt);
	}

	function buyTokens(address _to) tokenPhaseIsActive whenNotPaused payable {
		require(whitelist[_to]);
		require(msg.value >= ethMin && msg.value <= ethMax);
		require(_to != 0x0);
		address from = getPhaseAddress();
		assert(from != 0x0);
		uint256 weiAmount = msg.value;
		uint256 tokens = weiAmount * currentPhaseRate;
		weiRaised = weiRaised.add(weiAmount);
		wallet.transfer(weiAmount);
		if(!token.transferFromTokenSell(_to, from, tokens)) revert();
		TokenPurchased(_to, tokens, weiAmount);
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

	function finalizePhase() onlyOwner {
		if(currentPhase == CurrentPhase.Privatesale)
			token.finalizePrivatesale();
		else if(currentPhase == CurrentPhase.Presale)
			token.finalizePresale();
		TokenPhaseEnded(currentPhase);
	}

	function finalizeIto(uint256 _burnAmount, uint256 _ecoAmount, uint256 _airdropAmount) onlyOwner {
		token.finalizeCrowdsale(_burnAmount, _ecoAmount, _airdropAmount);
	}
}
