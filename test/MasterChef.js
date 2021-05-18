const { expect } = require('chai')

const pacocaPerBlock = 255.55
const hex = num => '0x' + Math.floor(num).toString(16)
const toString = num => num.toString() // / 1e18

describe('MasterChef Contract', () => {
    let MasterChef, masterChef,
        Pacoca, pacoca,
        wallets, dev, alice, bob

    const getInfo = async user => {
        const rewards = await masterChef.pendingSushi(0, user.address)
        const userInfo = await masterChef.userInfo(0, user.address)

        return {
            rewards: toString(rewards),
            deposit: toString(userInfo.amount),
            debt: toString(userInfo.rewardDebt),
        }
    }

    beforeEach(async () => {
        Pacoca = await ethers.getContractFactory('Pacoca')
        pacoca = await Pacoca.deploy()

        wallets = await ethers.getSigners()
        dev = wallets[0]
        alice = wallets[1]
        bob = wallets[2]

        MasterChef = await ethers.getContractFactory('MasterChef')
        masterChef = await MasterChef.deploy(
            pacoca.address,
            dev.address,
            hex(pacocaPerBlock * Math.pow(10, 18)),
            hex(20),
        )

        await pacoca.mint(bob.address, hex((100000000 - 1000) * Math.pow(10, 18)))
        await pacoca.transferOwnership(masterChef.address)

        await masterChef.add(1000, pacoca.address, false)
    })

    describe('Deployment', () => {
        it('Should set the right owners', async () => {
            expect(await pacoca.owner()).to.equal(masterChef.address)
            expect(await masterChef.owner()).to.equal(wallets[0].address)
        })
    })

    describe('Earn', () => {
        it('Should deposit, earn and withdraw', async () => {
            // Increase allowance
            await pacoca
                .connect(bob)
                .increaseAllowance(masterChef.address, hex(999999 * Math.pow(10, 18)))

            // Deposit tokens to masterchef
            await masterChef
                .connect(bob)
                .deposit(0, hex(Math.pow(10, 18)))

            // Skip some blocks
            for (let i = 0; i < 35; i++) {
                await masterChef.connect(bob).withdraw(0, 0)
            }

            console.log(await getInfo(bob))

            await masterChef
                .connect(bob)
                .withdraw(0, hex(Math.pow(10, 18)))

            console.log(await getInfo(bob))

            const bobBalance = await pacoca.balanceOf(bob.address)
            const contractBalance = await pacoca.balanceOf(masterChef.address)
            const totalSupply = await pacoca.totalSupply()

            // console.log('p', await masterChef.pendingSushi(bob.address))

            // expect(bobBalance.add(contractBalance)).to.equal(totalSupply)
            expect(bobBalance).to.equal(totalSupply)
        })
    })
})
