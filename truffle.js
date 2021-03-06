module.exports = {
	networks: {
	   development: {
			host: "127.0.0.1",
			port: 7545,
			gas: 6721975,
			network_id: "*" // Match any network id
		},
		 ropsten: {
			host: 'https://ropsten.infura.io/',
			port: 8545,
			network_id: 3,
			gas: 4612386
		},
	}
};
