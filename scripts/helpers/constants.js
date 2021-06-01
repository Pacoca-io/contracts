const addresses = {
    WBNB: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
    BURN: '0x000000000000000000000000000000000000dead',

    // Pacoca
    PACOCA_FARM: '0x55410d946dfab292196462ca9be9f3e4e4f337dd',
    PACOCA_FARM_TEST: '0x6c269a28909cad47aa4c5c28f9ff7b45fb97a3fd',
    PACOCA_TOKEN: '0x55671114d774ee99d653d6c12460c780a67f1d18',
    PACOCA_TOKEN_TEST: '0x43a064380bffc936e45a2834D2bC9fEf4A28d501',

    // CafeSwap
    BREW: '0x790be81c3ca0e53974be2688cdb954732c9862e1',
    CAFE_MASTERCHEF: '0xc772955c33088a97D56d0BBf473d05267bC4feBB',
    CAFE_ROUTER: '0x933DAea3a5995Fb94b14A7696a5F3ffD7B1E385A',

    // PancakeSwap
    CAKE: '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
    PANCAKE_MASTERCHEF: '0x73feaa1ee314f8c655e354234017be2193c9e24e',
    PANCAKE_ROUTER: '0x10ED43C718714eb63d5aA57B78B54704E256024E',
}

const constants = {
    ...addresses,

    // Platforms
    CAFE_SWAP: 'CAFE_SWAP',
    PANCAKE_SWAP: 'PANCAKE_SWAP',
}

for (const name in addresses) {
    constants[name] = addresses[name].toLowerCase()
}

module.exports = constants
