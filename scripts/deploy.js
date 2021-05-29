const cafeStratSetup = require('./cafeStratSetup')

const numberFormatter = new Intl.NumberFormat('en-US')
const exponent = ethers.BigNumber.from(10).pow(18)

const brewBnbFarm = {
    pid: 14,
    lpAddress: '0x4D1f8F8E579096097809D439d6707f2F5870652A',
    token0: '0x790Be81C3cA0e53974bE2688cDb954732C9862e1',
    token1: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
}

const mintAllocatedTokens = async ({ pacocaTokenContract }) => {
    const owner = (await ethers.getSigners())[0]
    const oneMillionTokens = ethers.BigNumber.from(10).pow(6).mul(exponent)

    const allocations = [
        {
            name: 'Partner Farming',
            address: owner.address, // TODO get address
            amount: ethers.BigNumber.from(10).mul(oneMillionTokens), // 10M tokens
        },
        {
            name: 'ICO',
            address: owner.address, // TODO get address
            amount: ethers.BigNumber.from(10).mul(oneMillionTokens), // 10M tokens
        },
        {
            name: 'Airdrops',
            address: owner.address, // TODO get address
            amount: ethers.BigNumber.from(8).mul(oneMillionTokens), // 8M tokens
        },
        {
            name: 'Initial Liquidity',
            address: owner.address, // TODO get address
            amount: ethers.BigNumber.from(2).mul(oneMillionTokens), // 2M tokens
        },
    ]

    for (const allocation of allocations) {
        await pacocaTokenContract.mint(allocation.address, allocation.amount)

        const parsedAmount = numberFormatter
            .format(allocation.amount.div(exponent).toNumber())

        console.log(`Minted ${ allocation.name } tokens`)
        console.log(`${ parsedAmount } to ${ allocation.address }`)
        console.log(`---------------------------------------------------------`)
    }
}

async function main() {
    // Deploy pacoca token
    const Pacoca = await ethers.getContractFactory('Pacoca')
    const pacoca = await Pacoca.deploy()

    // Mint allocated tokens
    await mintAllocatedTokens({ pacocaTokenContract: pacoca })

    // Deploy Pacoca Farm
    const PacocaFarm = await ethers.getContractFactory('PacocaFarm')
    const pacocaFarm = await PacocaFarm.deploy(pacoca.address, 7862758)

    // Deploy Pacoca Strategy
    const StratPacoca = await ethers.getContractFactory('StratPacoca')
    const stratPacoca = await StratPacoca.deploy(pacoca.address, pacocaFarm.address)

    // Deploy CafeLP Strategy
    const brewBnbStrat = cafeStratSetup({
        owner: (await ethers.getSigners())[0].address,
        pacocaFarm: pacocaFarm.address,
        pacoca: pacoca.address,
        wantAddress: brewBnbFarm.lpAddress,
        token0Address: brewBnbFarm.token0,
        token1Address: brewBnbFarm.token1,
    })
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

    await pacocaFarm.addPool(
        1000,
        pacoca.address,
        false,
        stratPacoca.address,
    )
    await pacocaFarm.addPool(
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
