const { expect } = require('chai')

describe('Airdrop Contract', () => {
    let OneInch, oneInch,
        BnbSwap, bnbSwap,
        Pacoca, pacoca,
        PacocaNFTs, pacocaNFTs,
        PacocaAirdrop, pacocaAirdrop,
        wallets

    beforeEach(async () => {
        OneInch = await ethers.getContractFactory('OneInchMock')
        oneInch = await OneInch.deploy()

        BnbSwap = await ethers.getContractFactory('BnbSwap')
        bnbSwap = await BnbSwap.deploy()

        Pacoca = await ethers.getContractFactory('Pacoca')
        pacoca = await Pacoca.deploy()

        PacocaNFTs = await ethers.getContractFactory('PacocaNFTs')
        pacocaNFTs = await PacocaNFTs.deploy()

        PacocaAirdrop = await ethers.getContractFactory('PacocaAirdrop')
        pacocaAirdrop = await PacocaAirdrop.deploy(
            oneInch.address,
            bnbSwap.address,
            pacoca.address,
            pacocaNFTs.address,
        )

        wallets = await ethers.getSigners()
    })

    describe('Deployment', () => {
        it('Should set the right owner', async () => {
            expect(await pacoca.owner()).to.equal(wallets[0].address)
        })
    })

    describe('Swap', () => {
        it('Should split values properly between Pacoca and 1inch', async () => {
            const wallet1 = wallets[1]
            const tx = {
                to: pacocaAirdrop.address,
                value: 100000,
                data: '0x00',
            }
            const expectedFee = tx.value * 0.5 / 100

            await expect(() => wallet1.sendTransaction(tx))
                .to.changeEtherBalance(pacocaAirdrop, expectedFee)

            await expect(() => wallet1.sendTransaction(tx))
                .to.changeEtherBalance(oneInch, tx.value - expectedFee)
        })
    })
})
