const cafeStratSetup = require('./cafeStratSetup')
const exponent = ethers.BigNumber.from(10).pow(18)

const brewBnbFarm = {
    pid: 14,
    lpAddress: '0x4D1f8F8E579096097809D439d6707f2F5870652A',
    token0: '0x790Be81C3cA0e53974bE2688cDb954732C9862e1',
    token1: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
}

async function main() {
    // We get the contract to deploy
    const Pacoca = await ethers.getContractFactory('Pacoca')
    const pacoca = await Pacoca.deploy()

    const owner = (await ethers.getSigners())[0]
    await pacoca.mint(
        owner.address,
        ethers.BigNumber.from(1000).mul(exponent),
    )

    const PacocaFarm = await ethers.getContractFactory('PacocaFarm')
    const pacocaFarm = await PacocaFarm.deploy(pacoca.address)

    const brewBnbStrat = cafeStratSetup({
        owner: (await ethers.getSigners())[0].address,
        pacocaFarm: pacocaFarm.address,
        pacoca: pacoca.address,
        wantAddress: brewBnbFarm.lpAddress,
        token0Address: brewBnbFarm.token0,
        token1Address: brewBnbFarm.token1,
    })

    const StratPacoca = await ethers.getContractFactory('StratPacoca')
    const stratPacoca = await StratPacoca.deploy(pacoca.address, pacocaFarm.address)

    const StratX2_CAFE = await ethers.getContractFactory('StratX2_CAFE')
    const stratX2_CAFE = await StratX2_CAFE.deploy(
        brewBnbStrat.addresses,
        brewBnbFarm.pid,
        false,
        false,
        true,
        brewBnbStrat.earnedToAUTOPath,
        brewBnbStrat.earnedToToken0Path,
        brewBnbStrat.earnedToToken1Path,
        brewBnbStrat.token0ToEarnedPath,
        brewBnbStrat.token1ToEarnedPath,
        190,
        150,
        9990,
        10000,
    )

    await pacoca.transferOwnership(pacocaFarm.address)
    await pacocaFarm.add(
        1000,
        brewBnbFarm.lpAddress,
        false,
        stratPacoca.address,
    )
    await pacocaFarm.add(
        500,
        brewBnbFarm.lpAddress,
        false,
        stratX2_CAFE.address,
    )

    console.log({
        farm: pacocaFarm.address,
        token: pacoca.address,
        stratPacoca: stratPacoca.address,
        stratX2_CAFE: stratX2_CAFE.address,
    })
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
