const { expect } = require('chai')

const exponent = ethers.BigNumber.from(10).pow(18)
const toEther = number => ethers.BigNumber.from(number).mul(exponent)

describe('PacocaFarm Contract', () => {
    let PacocaFarm, pacocaFarm,
        Pacoca, pacoca,
        Strat, strat,
        wallets, dev, alice, bob

    beforeEach(async () => {
        Pacoca = await ethers.getContractFactory('Pacoca')
        pacoca = await Pacoca.deploy()

        wallets = await ethers.getSigners()
        dev = wallets[0]
        alice = wallets[1]
        bob = wallets[2]

        PacocaFarm = await ethers.getContractFactory('PacocaFarm')
        pacocaFarm = await PacocaFarm.deploy(pacoca.address)

        Strat = await ethers.getContractFactory('StratPacoca')
        strat = await Strat.deploy(pacoca.address, pacocaFarm.address)

        await pacoca.mint(bob.address, toEther(10))
        await pacoca.mint(alice.address, toEther(10))
        await pacocaFarm.addPool(10, pacoca.address, false, strat.address)
        await pacoca.transferOwnership(pacocaFarm.address)
        await strat.transferOwnership(pacocaFarm.address)
    })

    describe('Deployment', () => {
        it('Should set the right owners', async () => {
            expect(await pacoca.owner()).to.equal(pacocaFarm.address)
            expect(await strat.owner()).to.equal(pacocaFarm.address)
            expect(await pacocaFarm.owner()).to.equal(dev.address)
            expect(await strat.govAddress()).to.equal(dev.address)
        })
    })

    describe('Governance', () => {
        it('Only governor can trigger governance functions', async () => {
            await strat.connect(dev).setSettings(9950, 9950)
            await expect(strat.connect(bob).setSettings(9950, 9950))
                .to.be.revertedWith('!gov')
        })
    })

    describe('Add pools', () => {
        it('Should allow only one pool of each token', async () => {
            await pacocaFarm.addPool(10, bob.address, false, strat.address)
            await expect(pacocaFarm.addPool(10, bob.address, false, strat.address))
                .to.be.revertedWith('Can\'t add another pool of same asset')
        })
    })

    describe('Earn', () => {
        it('Should deposit, earn and withdraw', async () => {
            // Increase allowance
            await pacoca
                .connect(bob)
                .increaseAllowance(pacocaFarm.address, toEther(999999))
            await pacoca
                .connect(alice)
                .increaseAllowance(pacocaFarm.address, toEther(999999))

            // Deposit tokens to masterchef
            await pacocaFarm
                .connect(bob)
                .deposit(0, toEther(1))

            // Skip some blocks
            for (let i = 0; i < 10; i++) {
                await ethers.provider.send('evm_mine')
            }

            await pacocaFarm
                .connect(alice)
                .deposit(0, toEther(1))

            await ethers.provider.send('evm_mine')

            // Bob's Balance
            // 11 x full block rewards + 1/2 block reward
            expect(await pacocaFarm.pendingPACOCA(0, bob.address)).to.equal(toEther(11 * 2 + 1))
            expect(await pacocaFarm.stakedWantTokens(0, bob.address)).to.equal(toEther(1))

            // Alice's Balance
            // 1/2 block reward
            expect(await pacocaFarm.pendingPACOCA(0, alice.address)).to.equal(toEther(1))
            expect(await pacocaFarm.stakedWantTokens(0, alice.address)).to.equal(toEther(1))

            // Withdraw deposits
            await pacocaFarm.connect(bob).withdraw(0, toEther(1))
            await pacocaFarm.connect(alice).withdraw(0, toEther(1))

            // Bob's Balance
            // 11 x full block rewards + 2 x 1/2 block reward
            expect(await pacocaFarm.pendingPACOCA(0, bob.address)).to.equal(toEther(0))
            expect(await pacoca.balanceOf(bob.address)).to.equal(toEther(10 + 11 * 2 + 2))

            // Alice's Balance
            // 2 x 1/2 block reward + 1 full block
            expect(await pacocaFarm.pendingPACOCA(0, alice.address)).to.equal(toEther(0))
            expect(await pacoca.balanceOf(alice.address)).to.equal(toEther(10 + 2 + 2))
        })
    })
})
