const wbnb = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'.toLowerCase()
const brew = '0x790be81c3ca0e53974be2688cdb954732c9862e1'.toLowerCase()
const cafeChef = '0xc772955c33088a97D56d0BBf473d05267bC4feBB'
const router = '0x933DAea3a5995Fb94b14A7696a5F3ffD7B1E385A'
const burn = '0x000000000000000000000000000000000000dead'

const getEarnedToTokenPath = token => token === brew
    ? []
    : token === wbnb
        ? [brew, wbnb]
        : [brew, wbnb, token]

const getTokenToEarnedPath = token => token === brew
    ? []
    : token === wbnb
        ? [wbnb, brew]
        : [token, wbnb, brew]

module.exports = ({ pacocaFarm, pacoca, wantAddress, token0Address, token1Address }) => {
    token0Address = token0Address.toLowerCase()
    token1Address = token1Address.toLowerCase()

    return {
        addresses: [
            wbnb,
            process.env.BSC_CONTROLLER_ADDRESS,
            pacocaFarm,
            pacoca,

            wantAddress,
            token0Address,
            token1Address,
            brew,

            cafeChef,
            router,
            process.env.BSC_REWARDS_ADDRESS,
            burn,
        ],

        earnedToAUTOPath: [brew, wbnb, pacoca],

        earnedToToken0Path: getEarnedToTokenPath(token0Address),
        earnedToToken1Path: getEarnedToTokenPath(token1Address),

        token0ToEarnedPath: getTokenToEarnedPath(token0Address),
        token1ToEarnedPath: getTokenToEarnedPath(token1Address),
    }
}
