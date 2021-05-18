const { expect } = require('chai')

describe('Token Allocation Contract', () => {
    let Pacoca, pacoca,
        TokenAllocation, tokenAllocation,
        wallets, owner, bob

    const allocations = [
        20 * Math.pow(10, 6),
        15 * Math.pow(10, 6),
        10 * Math.pow(10, 6),
        8 * Math.pow(10, 6),
        5 * Math.pow(10, 6),
        2 * Math.pow(10, 6),
    ]

    const exponent = ethers.BigNumber.from(10).pow(18)
    const toEther = number => ethers.BigNumber.from(number).mul(exponent)

    beforeEach(async () => {
        Pacoca = await ethers.getContractFactory('Pacoca')
        pacoca = await Pacoca.deploy()

        TokenAllocation = await ethers.getContractFactory('TokenAllocation')
        tokenAllocation = await TokenAllocation.deploy(pacoca.address)

        wallets = await ethers.getSigners()
        owner = wallets[0]
        bob = wallets[1]

        pacoca.mint(
            tokenAllocation.address,
            ethers.BigNumber.from(60).mul(Math.pow(10, 6)).mul(exponent),
        )
    })

    describe('Deployment', () => {
        it('Should set the right owner', async () => {
            expect(await pacoca.owner()).to.equal(owner.address)
            expect(await tokenAllocation.owner()).to.equal(owner.address)
        })
    })

    describe('Token Allocation', () => {
        it('Should set the right allocations', async () => {
            await Promise.all(allocations.map(
                async (allocation, index) =>
                    expect((await tokenAllocation.allocations(index)).total)
                        .to.equal(toEther(allocation)),
            ))
        })

        it('Should calculate minted percentage', async () => {
            expect(await tokenAllocation.percentageMintedByChef()).to.equal(0)

            await pacoca.mint(bob.address, toEther(30000000))

            expect(await tokenAllocation.percentageMintedByChef()).to.equal(7500)
        })

        it('Should vest tokens properly', async () => {
            // Initial balance is zero
            expect(await pacoca.balanceOf(owner.address)).to.equal(0)

            await pacoca.mint(bob.address, toEther(10000000))

            await tokenAllocation.claimDevFunds()

            // Bob shouldn't be able to claim funds
            await expect(tokenAllocation.connect(bob).claimDevFunds())
                .to.be.revertedWith('Ownable: caller is not the owner')

            // Balance should be 25% of dev allocation
            expect(await pacoca.balanceOf(owner.address))
                .to.equal(toEther(allocations[1] * 0.25))

            await pacoca.mint(bob.address, toEther(30000000))

            await tokenAllocation.claimDevFunds()

            // Balance should be 100% of dev allocation
            expect(await pacoca.balanceOf(owner.address))
                .to.equal(toEther(allocations[1]))
        })

        it('Should send partner funds', async () => {
            const destination = wallets[5].address

            await tokenAllocation.sendPartnerFarmingFunds(destination, toEther(19000000))

            expect(await pacoca.balanceOf(destination)).to.equal(toEther(19000000))

            await expect(tokenAllocation.sendPartnerFarmingFunds(
                destination,
                toEther(1000001),
            )).to.be.revertedWith('TokenAllocation: Requested amount not available')

            await tokenAllocation.sendPartnerFarmingFunds(destination, toEther(1000000))

            expect(await pacoca.balanceOf(destination)).to.equal(toEther(20000000))
        })
    })
})
