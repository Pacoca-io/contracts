const { expect } = require('chai')

describe('Marketplace', () => {
    let PacocaCollectibles, pacocaCollectibles,
        dev, bob

    beforeEach(async () => {
        PacocaCollectibles = await ethers.getContractFactory('PacocaCollectibles')
        pacocaCollectibles = await PacocaCollectibles.deploy()

        const wallets = await ethers.getSigners()

        dev = wallets[0]
        bob = wallets[1]
    })

    describe('Deployment', () => {
        it('Should set the right owner', async () => {
            expect(await pacocaCollectibles.owner()).to.equal(dev.address)
        })
    })

    describe('NFT Contract', () => {
        it('Should return metadata URI', async () => {
            await pacocaCollectibles.mint(dev.address, 0, 1, '0x00')

            expect(await pacocaCollectibles.uri(0))
                .to.equal('https://api.pacoca.io/nfts/')

            expect(await pacocaCollectibles.getCollectibleURI(0))
                .to.equal('https://api.pacoca.io/nfts/0.json')
        })
    })
})
