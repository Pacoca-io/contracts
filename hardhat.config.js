require('dotenv').config()

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('@nomiclabs/hardhat-waffle')

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
}
