const hre = require('hardhat')

const run = async () => {
    const Contract = await hre.ethers.getContractFactory('Earn')
    const contract = await Contract.deploy()

    console.log(contract.address)
}

run()
