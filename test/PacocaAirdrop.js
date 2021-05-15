const { expect } = require('chai')

describe('Airdrop Contract', () => {
    let BnbSwap, bnbSwap,
        Pacoca, pacoca,
        PacocaNFTs, pacocaNFTs,
        PacocaAirdrop, pacocaAirdrop,
        owner, addr1, addr2

    beforeEach(async () => {
        BnbSwap = await ethers.getContractFactory('BnbSwap')
        bnbSwap = await BnbSwap.deploy()

        Pacoca = await ethers.getContractFactory('Pacoca')
        pacoca = await Pacoca.deploy()

        PacocaNFTs = await ethers.getContractFactory('PacocaNFTs')
        pacocaNFTs = await PacocaNFTs.deploy()

        PacocaAirdrop = await ethers.getContractFactory('PacocaAirdrop')
        pacocaAirdrop = await PacocaAirdrop.deploy(bnbSwap.address, pacoca.address, pacocaNFTs.address);

        [owner, addr1, addr2] = await ethers.getSigners()
    })

    describe('Deployment', () => {
        it('Should set the right owner', async () => {
            expect(await pacoca.owner()).to.equal(owner.address)
        })
    })
})
