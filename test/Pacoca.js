const { expect } = require('chai')

describe('Pacoca Token Contract', () => {
    let Pacoca, pacoca, owner, addr1, addr2

    beforeEach(async () => {
        Pacoca = await ethers.getContractFactory('Pacoca')
        pacoca = await Pacoca.deploy();
        [owner, addr1, addr2] = await ethers.getSigners()
    })

    describe('Deployment', () => {
        it('Should set the right owner', async () => {
            expect(await pacoca.owner()).to.equal(owner.address)
        })
    })
})
