const hre = require('hardhat')
const cafeStratSetup = require('./helpers/cafe-strat-setup')
const CONSTANTS = require('./helpers/constants')

const getTokensInLP = async ({ lp }) => {
    const abi = [
        'function token0() external view returns (address)',
        'function token1() external view returns (address)',
    ]

    const contract = new hre.ethers.Contract(lp, abi, hre.ethers.provider)

    return {
        token0: await contract.token0(),
        token1: await contract.token1(),
    }
}

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
        200,
        9995,
        10000,
    )

    console.log('strat address: ', strat.address)

    return strat
}

const run = async () => {
    const farmInfo = {
        pid: 252,
        wantAddress: '0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16',
        isCAKEStaking: false,
        platform: CONSTANTS.PANCAKE_SWAP,
    }

    await deployCafeStrat({
        farmInfo: {
            ...farmInfo,
            ...await getTokensInLP({ lp: farmInfo.wantAddress })
        },
        pacocaFarm: CONSTANTS.PACOCA_FARM,
        pacoca: CONSTANTS.PACOCA_TOKEN,
    })
}

run()
