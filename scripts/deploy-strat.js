const hre = require('hardhat')
const cafeStratSetup = require('./helpers/cafe-strat-setup')
const CONSTANTS = require('./helpers/constants')

const deployCafeStrat = async ({ farmInfo, pacoca, pacocaFarm }) => {
    const stratData = cafeStratSetup({
        pacocaFarm: pacocaFarm,
        pacoca: pacoca,
        wantAddress: farmInfo.wantAddress,
        token0Address: farmInfo.token0,
        token1Address: farmInfo.token1,
        isCAKEStaking: farmInfo.isCAKEStaking,
        platform: farmInfo.platform,
    })
    const StratX2_CAFE = await hre.ethers.getContractFactory('StratX2_CAFE')

    const strat = await StratX2_CAFE.deploy(
        stratData.addresses,
        farmInfo.pid,
        farmInfo.isCAKEStaking || false, // Is cake staking
        false,
        true,
        stratData.earnedToAUTOPath,
        stratData.earnedToToken0Path,
        stratData.earnedToToken1Path,
        stratData.token0ToEarnedPath,
        stratData.token1ToEarnedPath,
        150,
        150,
        9990,
        10000,
    )

    console.log('strat address: ', strat.address)

    return strat
}

const run = async () => {
    const farmInfo = {
        pid: 0,
        wantAddress: CONSTANTS.CAKE,
        token0: '0x0000000000000000000000000000000000000000',
        token1: '0x0000000000000000000000000000000000000000',
        isCAKEStaking: true,
        platform: CONSTANTS.PANCAKE_SWAP,
    }

    await deployCafeStrat({
        farmInfo,
        pacocaFarm: CONSTANTS.PACOCA_FARM,
        pacoca: CONSTANTS.PACOCA_TOKEN,
    })
}

run()
