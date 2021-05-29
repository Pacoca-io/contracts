const cafeStratSetup = require('./helpers/cafe-strat-setup')
const breakLine = require('./helpers/break-line')
const exponent = require('./helpers/exponent')

const numberFormatter = new Intl.NumberFormat('en-US')

const brewBnbFarm = {
    pid: 14,
    lpAddress: '0x4D1f8F8E579096097809D439d6707f2F5870652A',
    token0: '0x790Be81C3cA0e53974bE2688cDb954732C9862e1',
    token1: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
}

const deployToken = async () => {
    const Pacoca = await ethers.getContractFactory('Pacoca')
    return await Pacoca.deploy()
}

const mintAllocatedTokens = async ({ pacoca }) => {
    const owner = (await ethers.getSigners())[0]
    const oneMillionTokens = ethers.BigNumber.from(10).pow(6).mul(exponent)

    const allocations = [
        {
            name: 'Partner Farming',
            address: process.env.BSC_PARTNER_FARMING_ADDRESS,
            amount: ethers.BigNumber.from(10).mul(oneMillionTokens), // 10M tokens
        },
        {
            name: 'ICO',
            address: owner.address, // TODO get address
            amount: ethers.BigNumber.from(10).mul(oneMillionTokens), // 10M tokens
        },
        {
            name: 'Airdrops',
            address: process.env.BSC_AIRDROP_ADDRESS,
            amount: ethers.BigNumber.from(8).mul(oneMillionTokens), // 8M tokens
        },
        {
            name: 'Initial Liquidity',
            address: process.env.BSC_LIQUIDITY_ADDRESS,
            amount: ethers.BigNumber.from(2).mul(oneMillionTokens), // 2M tokens
        },
    ]

    console.log('Allocated tokens:')
    console.log()

    for (const allocation of allocations) {
        await pacoca.mint(allocation.address, allocation.amount)

        const parsedAmount = numberFormatter
            .format(allocation.amount.div(exponent).toNumber())

        console.log(`Minted ${ allocation.name } tokens`)
        console.log(`${ parsedAmount } to ${ allocation.address }`)
        breakLine()
    }
}

const deployFarm = async ({ pacoca }) => {
    const PacocaFarm = await ethers.getContractFactory('PacocaFarm')
    const pacocaFarm = await PacocaFarm.deploy(pacoca.address, 7862758)

    await pacoca.transferOwnership(pacocaFarm.address)
    await pacocaFarm.setPacocaPerBlock(ethers.BigNumber.from(10).mul(exponent))

    return pacocaFarm
}

const deployPacocaStrat = async ({ pacoca, pacocaFarm }) => {
    const StratPacoca = await ethers.getContractFactory('StratPacoca')
    const stratPacoca = await StratPacoca.deploy(
        pacoca.address,
        pacocaFarm.address,
        process.env.BSC_CONTROLLER_ADDRESS,
    )

    await pacocaFarm.addPool(
        1000,
        pacoca.address,
        false,
        stratPacoca.address,
    )

    return stratPacoca
}

const deployCafeStrat = async ({ pacoca, pacocaFarm }) => {
    const brewBnbStrat = cafeStratSetup({
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

    await pacocaFarm.addPool(
        500,
        brewBnbFarm.lpAddress,
        false,
        stratX2_CAFE.address,
    )

    return stratX2_CAFE
}

async function main() {
    // Deploy pacoca token
    const pacoca = await deployToken()

    // Mint allocated tokens
    await mintAllocatedTokens({ pacoca })

    // Deploy Pacoca Farm
    const pacocaFarm = await deployFarm({ pacoca })

    // Deploy Pacoca Strategy
    const pacocaStrat = await deployPacocaStrat({ pacoca, pacocaFarm })

    // Deploy CafeLP Strategy
    const brewBnbStrat = await deployCafeStrat({ pacoca, pacocaFarm })

    await pacocaFarm.transferOwnership(process.env.BSC_CONTROLLER_ADDRESS)

    console.log()
    console.log('Contract Addresses:')
    console.log()

    console.log(`Pacoca Token`)
    console.log(`address: ${ pacoca.address }`)
    console.log(`owner: ${ await pacoca.owner() }`)
    breakLine()
    console.log(`Pacoca Farm`)
    console.log(`address: ${ pacocaFarm.address }`)
    console.log(`owner: ${ await pacocaFarm.owner() }`)
    console.log(`pacoca/block: ${ await pacocaFarm.PACOCAPerBlock() }`)
    breakLine()
    console.log(`PACOCA Strat`)
    console.log(`address: ${ pacocaStrat.address }`)
    console.log(`owner: ${ await pacocaStrat.owner() }`)
    console.log(`gov: ${ await pacocaStrat.govAddress() }`)
    breakLine()
    console.log(`BREW-BNB Strat`)
    console.log(`address: ${ brewBnbStrat.address }`)
    console.log(`owner: ${ await brewBnbStrat.owner() }`)
    console.log(`gov: ${ await brewBnbStrat.govAddress() }`)
    console.log(`rewards: ${ await brewBnbStrat.rewardsAddress() }`)
    breakLine()
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
