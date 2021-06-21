require('dotenv').config()

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('@nomiclabs/hardhat-waffle')
require('hardhat-gas-reporter')

module.exports = {
    solidity: {
        version: '0.6.12',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    networks: {
        bscTest: {
            url: 'https://bsc-dataseed.binance.org',
            accounts: [process.env.BSC_TEST_PRIVATE_KEY],
        },
        bsc: {
            url: 'https://bsc-dataseed.binance.org',
            accounts: [process.env.BSC_PRIVATE_KEY],
        },
    },
    abiExporter: {
        clear: true,
        only: ['Pacoca', 'StratX2'],
        spacing: 4,
    },
    gasReporter: {
        currency: 'USD',
        gasPrice: 5,
    },
}
