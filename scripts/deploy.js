const cafeStratSetup = require('./cafeStratSetup')

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

    const PacocaFarm = await ethers.getContractFactory('PacocaFarm')
    const pacocaFarm = await PacocaFarm.deploy(pacoca.address)

    await pacoca.transferOwnership(pacocaFarm.address)

    console.log(cafeStratSetup({
        owner: (await ethers.getSigners())[0].address,
        pacocaFarm: pacocaFarm.address,
        pacoca: pacoca.address,
        wantAddress: brewBnbFarm.lpAddress,
        token0Address: brewBnbFarm.token0,
        token1Address: brewBnbFarm.token1,
    }))
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
