pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";


contract TTTToken is ERC20, Ownable {
	using SafeMath for uint;

	string public constant name = "The Tip Token";
	string public constant symbol = "TTT";

	uint8 public decimals = 18;

	mapping(address=>uint256) balances;
	mapping(address=>mapping(address=>uint256)) allowed;

	// Supply variables
	uint256 public totalSupply_;
	uint256 public presaleSupply;
	uint256 public crowdsaleSupply;
	uint256 public privatesaleSupply;
	uint256 public airdropSupply;
	uint256 public teamSupply;
	uint256 public ecoSupply;

	// Vest variables
	uint256 public firstVestStartsAt;
	uint256 public secondVestStartsAt;
	uint256 public firstVestAmount;
	uint256 public secondVestAmount;

	uint256 public crowdsaleBurnAmount;

	// Token sale addresses
	address public privatesaleAddress;
	address public presaleAddress;
	address public crowdsaleAddress;
	address public teamSupplyAddress;
	address public ecoSupplyAddress;
	address public crowdsaleAirdropAddress;
	address public crowdsaleBurnAddress;
	address public tokenSaleAddress;

	// Token sale state variables
	bool public privatesaleFinalized;
	bool public presaleFinalized;
	bool public crowdsaleFinalized;

	event PrivatesaleFinalized(uint tokensRemaining);
	event PresaleFinalized(uint tokensRemaining);
	event CrowdsaleFinalized(uint tokensRemaining);
	event Burn(address indexed burner, uint256 value);
	event TokensaleAddressSet(address tSeller, address from);

	modifier onlyTokenSale() {
		require(msg.sender == tokenSaleAddress);
		_;
	}

	modifier canItoSend() {
		require(crowdsaleFinalized == true || (crowdsaleFinalized == false && msg.sender == ecoSupplyAddress));
		_;
	}

	function TTTToken() {
		// 600 million total supply divided into
		//		90 million to privatesale address
		//		120 million to presale address
		//		180 million to crowdsale address
		//		90 million to eco supply address
		//		120 million to team supply address
		totalSupply_ = 600000000 * 10**uint(decimals);
		privatesaleSupply = 90000000 * 10**uint(decimals);
		presaleSupply = 120000000 * 10**uint(decimals);
		crowdsaleSupply = 180000000 * 10**uint(decimals);
		ecoSupply = 90000000 * 10**uint(decimals);
		teamSupply = 120000000 * 10**uint(decimals);

		firstVestAmount = teamSupply.div(2);
		secondVestAmount = firstVestAmount;

		privatesaleAddress = 0x6876b854Bc0E2c59dc448949d1Caa5BF5bb08F54;
		presaleAddress = 0xcab76A29D35cc2f6B481112157675486180A560B;
		crowdsaleAddress = 0xb6d40Fb512e7c824c6a33861b233eE50c263A950;
		teamSupplyAddress = 0x4b1CCC3023C973A62984C865404f662e968c1FC1;
		ecoSupplyAddress = 0xb718C3f9D9947993BA752622a15dc6BBCA1d977d;
		crowdsaleAirdropAddress = 0x5BcFCbdE79895D3D6A115Baf5386ae5463df2aAF;
		crowdsaleBurnAddress = 0x48118545177666aF8eB9A265a57558f4A2bdbd7F;

		addToBalance(privatesaleAddress, privatesaleSupply);
		addToBalance(presaleAddress, presaleSupply);
		addToBalance(crowdsaleAddress, crowdsaleSupply);
		addToBalance(teamSupplyAddress, teamSupply);
		addToBalance(ecoSupplyAddress, ecoSupply);

		// 12/01/2018 @ 12:00am (UTC)
		firstVestStartsAt = 1543622400;
		// 06/01/2019 @ 12:00am (UTC)
		secondVestStartsAt = 1559347200;
	}

	// Transfer
	function transfer(address _to, uint256 _amount) public canItoSend returns (bool success) {
		require(balanceOf(msg.sender) >= _amount);
		addToBalance(_to, _amount);
		decrementBalance(msg.sender, _amount);
		Transfer(msg.sender, _to, _amount);
		return true;
	}

	// Transfer from one address to another
	function transferFrom(address _from, address _to, uint256 _amount) public canItoSend returns (bool success) {
		require(allowance(_from, msg.sender) >= _amount);
		decrementBalance(_from, _amount);
		addToBalance(_to, _amount);
		allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
		Transfer(_from, _to, _amount);
		return true;
	}

	// Function for token sell contract to call on transfers
	function transferFromTokenSell(address _to, address _from, uint256 _amount) external onlyTokenSale returns (bool success) {
		require(_amount > 0);
		require(_to != 0x0);
		require(balanceOf(_from) >= _amount);
		decrementBalance(_from, _amount);
		addToBalance(_to, _amount);
		Transfer(_from, _to, _amount);
		return true;
	}

	// Approve another address a certain amount of TTT
	function approve(address _spender, uint256 _value) public returns (bool success) {
		require((_value == 0) || (allowance(msg.sender, _spender) == 0));
		allowed[msg.sender][_spender] = _value;
		Approval(msg.sender, _spender, _value);
		return true;
	}

	// Get an address's TTT allowance
	function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
		return allowed[_owner][_spender];
	}

	// Get TTT balance of an address
	function balanceOf(address _owner) public view returns (uint256 balance) {
		return balances[_owner];
	}

	// Return total supply
	function totalSupply() public view returns (uint256 totalSupply) {
		return totalSupply_;
	}

	// Set the tokenSell contract address, can only be set once
	function setTokenSaleAddress(address _tokenSaleAddress) external onlyOwner {
		require(tokenSaleAddress == 0x0);
		tokenSaleAddress = _tokenSaleAddress;
		TokensaleAddressSet(tokenSaleAddress, msg.sender);
	}

	// Finalize private. If there are leftover TTT, overflow to presale
	function finalizePrivatesale() external onlyTokenSale returns (bool success) {
		require(privatesaleFinalized == false);
		uint256 amount = balanceOf(privatesaleAddress);
		if (amount != 0) {
			addToBalance(presaleAddress, amount);
			decrementBalance(privatesaleAddress, amount);
		}
		privatesaleFinalized = true;
		PrivatesaleFinalized(amount);
		return true;
	}

	// Finalize presale. If there are leftover TTT, overflow to crowdsale
	function finalizePresale() external onlyTokenSale returns (bool success) {
		require(presaleFinalized == false);
		uint256 amount = balanceOf(presaleAddress);
		if (amount != 0) {
			addToBalance(crowdsaleAddress, amount);
			decrementBalance(presaleAddress, amount);
		}
		presaleFinalized = true;
		PresaleFinalized(amount);
		return true;
	}

	// Finalize crowdsale. If there are leftover TTT, add 10% to airdrop, 20% to ecosupply, burn 70% at a later date
	function finalizeCrowdsale(uint256 _burnAmount, uint256 _ecoAmount, uint256 _airdropAmount) external onlyTokenSale returns(bool success) {
		require(presaleFinalized == true && crowdsaleFinalized == false);
		require((_burnAmount.add(_ecoAmount).add(_airdropAmount)) == crowdsaleSupply);
		uint256 amount = balanceOf(crowdsaleAddress);
		if (amount > 0) {
			crowdsaleBurnAmount = _burnAmount;
			addToBalance(ecoSupplyAddress, _ecoAmount);
			addToBalance(crowdsaleBurnAddress, crowdsaleBurnAmount);
			addToBalance(crowdsaleAirdropAddress, _airdropAmount);
			decrementBalance(crowdsaleAddress, amount);
			assert(balanceOf(crowdsaleAddress) == 0);
		}
		crowdsaleFinalized = true;
		CrowdsaleFinalized(amount);
		return true;
	}

	/**
	* @dev Burns a specific amount of tokens. * added onlyOwner, as this will only happen from owner, if there are crowdsale leftovers
	* @param _value The amount of token to be burned.
	* @dev imported from https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/token/ERC20/BurnableToken.sol
	*/
	function burn(uint256 _value) public onlyOwner {
		require(_value <= balances[msg.sender]);
		require(crowdsaleFinalized == true);
		// no need to require value <= totalSupply, since that would imply the
		// sender's balance is greater than the totalSupply, which *should* be an assertion failure

		address burner = msg.sender;
		balances[burner] = balances[burner].sub(_value);
		totalSupply_ = totalSupply_.sub(_value);
		Burn(burner, _value);
		Transfer(burner, address(0), _value);
	}

	// Transfer tokens from the vested address. 50% available 12/01/2018, the rest available 06/01/2019
	function transferFromVest(uint256 _amount) public onlyOwner {
		require(block.timestamp > firstVestStartsAt);
		require(_amount > 0);
		require(crowdsaleFinalized == true);
		if(block.timestamp > secondVestStartsAt) {
			// all tokens available for vest withdrawl
			require(_amount <= teamSupply);
			require(_amount <= balanceOf(teamSupplyAddress));
		} else {
			// only first vest available
			require(_amount <= firstVestAmount);
			require(_amount <= balanceOf(teamSupplyAddress));
		}
		addToBalance(msg.sender, _amount);
		decrementBalance(teamSupplyAddress, _amount);
		Transfer(teamSupplyAddress, msg.sender, _amount);
	}

	// Add to balance
	function addToBalance(address _address, uint _amount) internal {
		balances[_address] = balances[_address].add(_amount);
	}

	// Remove from balance
	function decrementBalance(address _address, uint _amount) internal {
		balances[_address] = balances[_address].sub(_amount);
	}

}
