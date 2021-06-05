const { expect } = require('chai')

describe('Pacoca Token Contract', () => {
    let Pacoca, pacoca,
        TokenTimelock, tokenTimelock,
        dev, bob

    beforeEach(async () => {
        Pacoca = await ethers.getContractFactory('Pacoca')
        pacoca = await Pacoca.deploy()

        const wallets = await ethers.getSigners()

        dev = wallets[0]
        bob = wallets[1]

        pacoca.mint(dev.address, 100000)

        TokenTimelock = await ethers.getContractFactory('TokenTimelock')
        tokenTimelock = await TokenTimelock.deploy(bob.address)
    })

    describe('Deployment', () => {
        it('Should set the right owner', async () => {
            expect(await pacoca.owner()).to.equal(dev.address)
            expect(await tokenTimelock.owner()).to.equal(bob.address)
        })
    })

    describe('Vest', () => {
        it('Should deposit tokens', async () => {
            await pacoca.connect(dev).transfer(tokenTimelock.address, 50000)

            expect(await pacoca.balanceOf(dev.address)).to.equal(50000)
            expect(await pacoca.balanceOf(tokenTimelock.address)).to.equal(50000)
        })

        it('Should withdraw tokens', async () => {
            await pacoca.connect(dev).transfer(tokenTimelock.address, 50000)
            const contractBalance = await pacoca.balanceOf(tokenTimelock.address)

            await expect(tokenTimelock.connect(bob)
                .withdraw(pacoca.address, contractBalance))
                .to.be.revertedWith('too early')

            const minute = 60
            const hours = 60
            const day = 24

            await ethers.provider.send('evm_increaseTime', [
                minute * hours * day * 40,
            ])

            await tokenTimelock.connect(bob).withdraw(pacoca.address, contractBalance)

            expect(await pacoca.balanceOf(bob.address)).to.equal(contractBalance)
            expect(await pacoca.balanceOf(bob.address)).to.equal(50000)
            expect(await pacoca.balanceOf(tokenTimelock.address)).to.equal(0)
        })
    })
})
