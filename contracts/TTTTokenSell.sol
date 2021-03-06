pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import "zeppelin-solidity/contracts/ownership/Whitelist.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./TTTToken.sol";

contract TTTTokenSell is Whitelist, Pausable {
	using SafeMath for uint;

	uint public decimals = 18;

	// TTTToken contract address
	address public tokenAddress;
	address public wallet;
	// Wallets for each phase - hardcap of each is balanceOf
	address public privatesaleAddress;
	address public presaleAddress;
	address public crowdsaleAddress;

	// Amount of wei currently raised
	uint256 public weiRaised;

	// Variables for phase start/end
	uint256 public startsAt;
	uint256 public endsAt;

	// minimum and maximum
	uint256 public ethMin;
	uint256 public ethMax;

	enum CurrentPhase { Privatesale, Presale, Crowdsale, None }

	CurrentPhase public currentPhase;
	uint public currentPhaseRate;
	address public currentPhaseAddress;

	TTTToken public token;

	event AmountRaised(address beneficiary, uint amountRaised);
	event TokenPurchased(address indexed purchaser, uint256 value, uint256 wieAmount);
	event TokenPhaseStarted(CurrentPhase phase, uint256 startsAt, uint256 endsAt);
	event TokenPhaseEnded(CurrentPhase phase);

	modifier tokenPhaseIsActive() {
		assert(now >= startsAt && now <= endsAt);
		_;
	}

	function TTTTokenSell() {
		wallet = 0xea2d2c0223af6e9c83db343aef2194564b27ee87;

		privatesaleAddress = 0x6876b854Bc0E2c59dc448949d1Caa5BF5bb08F54;
		presaleAddress = 0xcab76A29D35cc2f6B481112157675486180A560B;
		crowdsaleAddress = 0xb6d40Fb512e7c824c6a33861b233eE50c263A950;
		
		currentPhase = CurrentPhase.None;
		currentPhaseAddress = privatesaleAddress;
		startsAt = 0;
		endsAt = 0;
		ethMin = 0;
		ethMax = numToWei(1000, decimals);
	}
	
	function setTokenAddress(address _tokenAddress) external onlyOwner {
		require(tokenAddress == 0x0);
		tokenAddress = _tokenAddress;
		token = TTTToken(tokenAddress);
	}

	function startPhase(uint _phase, uint _currentPhaseRate, uint256 _startsAt, uint256 _endsAt) external onlyOwner {
		require(_phase >= 0 && _phase <= 2);
		require(_startsAt > endsAt && _endsAt > _startsAt);
		require(_currentPhaseRate > 0);
		currentPhase = CurrentPhase(_phase);
		currentPhaseAddress = getPhaseAddress();
		assert(currentPhaseAddress != 0x0);
		currentPhaseRate = _currentPhaseRate;
		if(currentPhase == CurrentPhase.Privatesale) ethMin = numToWei(10, decimals);
		else {
			ethMin = 0;
			ethMax = numToWei(15, decimals);
		}
		startsAt = _startsAt;
		endsAt = _endsAt;
		TokenPhaseStarted(currentPhase, startsAt, endsAt);
	}

	function buyTokens(address _to) tokenPhaseIsActive whenNotPaused payable {
		require(whitelist[_to]);
		require(msg.value >= ethMin && msg.value <= ethMax);
		require(_to != 0x0);
		uint256 weiAmount = msg.value;
		uint256 tokens = weiAmount.mul(currentPhaseRate);
		// 100% bonus for privatesale
		if(currentPhase == CurrentPhase.Privatesale) tokens = tokens.add(tokens);
		weiRaised = weiRaised.add(weiAmount);
		wallet.transfer(weiAmount);
		if(!token.transferFromTokenSell(_to, currentPhaseAddress, tokens)) revert();
		TokenPurchased(_to, tokens, weiAmount);
	}

	// To contribute, send a value transaction to the token sell Address.
	// Please include at least 100 000 gas.
	function () payable {
		buyTokens(msg.sender);
	}

	function finalizePhase() external onlyOwner {
		if(currentPhase == CurrentPhase.Privatesale) token.finalizePrivatesale();
		else if(currentPhase == CurrentPhase.Presale) token.finalizePresale();
		endsAt = block.timestamp;
		TokenPhaseEnded(currentPhase);
	}

	function finalizeIto(uint256 _burnAmount, uint256 _ecoAmount, uint256 _airdropAmount) external onlyOwner {
		token.finalizeCrowdsale(numToWei(_burnAmount, decimals), numToWei(_ecoAmount, decimals), numToWei(_airdropAmount, decimals));
		endsAt = block.timestamp;
		TokenPhaseEnded(currentPhase);
	}

	function getPhaseAddress() internal view returns (address phase) {
		if(currentPhase == CurrentPhase.Privatesale) return privatesaleAddress;
		else if(currentPhase == CurrentPhase.Presale) return presaleAddress;
		else if(currentPhase == CurrentPhase.Crowdsale) return crowdsaleAddress;
		return 0x0;
	}

	function numToWei(uint256 _num, uint _decimals) internal pure returns (uint256 w) {
		return _num.mul(10**_decimals);
	}
}
