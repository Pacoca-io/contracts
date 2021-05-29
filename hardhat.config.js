require('dotenv').config()

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('@nomiclabs/hardhat-waffle')
require('hardhat-abi-exporter')

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
}
