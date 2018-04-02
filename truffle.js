module.exports = {
	networks: {
	   development: {
			host: "127.0.0.1",
			port: 7545,
			network_id: "*" // Match any network id
		},
		 ropsten: {
			host: 'https://ropsten.infura.io/VYHM28f6EsD7dSXSHcmM',
			port: 8545,
			network_id: 3, 
			gas: 4612386
		},
	}
};
