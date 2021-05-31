const hre = require('hardhat')
const cafeStratSetup = require('./helpers/cafe-strat-setup')

const deployCafeStrat = async ({ farmInfo, pacoca, pacocaFarm }) => {
    const stratData = cafeStratSetup({
        pacocaFarm: pacocaFarm,
        pacoca: pacoca,
        wantAddress: farmInfo.lpAddress,
        token0Address: farmInfo.token0,
        token1Address: farmInfo.token1,
    })
    const StratX2_CAFE = await hre.ethers.getContractFactory('StratX2_CAFE')
    return await StratX2_CAFE.deploy(
        stratData.addresses,
        farmInfo.pid,
        false,
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
}

const run = async () => {
    const farmInfo = {
        pid: 38,
        lpAddress: '0xb9c7049cb298035640e7b6db219e68c348b976b7',
        token0: '0x55671114d774ee99d653d6c12460c780a67f1d18',
        token1: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
    }

    console.log(
        await deployCafeStrat({
            farmInfo,
            pacocaFarm: '0x55410d946dfab292196462ca9be9f3e4e4f337dd',
            pacoca: '0x55671114d774ee99d653d6c12460c780a67f1d18',
        }),
    )
}

run()
