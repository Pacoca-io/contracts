const CONSTANTS = require('./constants')
const tokenRouter = require('./token-router')

module.exports = ({ pacocaFarm, pacoca, wantAddress, token0Address, token1Address, isCAKEStaking, platform }) => {
    token0Address = token0Address.toLowerCase()
    token1Address = token1Address.toLowerCase()

    let masterchef
    let router
    let earnedToken

    switch (platform) {
        case CONSTANTS.CAFE_SWAP:
            masterchef = CONSTANTS.CAFE_MASTERCHEF
            router = CONSTANTS.CAFE_ROUTER
            earnedToken = CONSTANTS.BREW
            break
        case CONSTANTS.PANCAKE_SWAP:
            masterchef = CONSTANTS.PANCAKE_MASTERCHEF
            router = CONSTANTS.PANCAKE_ROUTER
            earnedToken = CONSTANTS.CAKE
            break
        default:
            throw new Error('Platform must be specified')
    }

    const addresses = [
        CONSTANTS.WBNB,
        process.env.BSC_CONTROLLER_ADDRESS,
        pacocaFarm,
        pacoca,

        wantAddress,
        token0Address,
        token1Address,
        earnedToken,

        masterchef,
        router,
        process.env.BSC_REWARDS_ADDRESS,
        CONSTANTS.BURN,
    ]

    const earnedToAUTOPath = [earnedToken, CONSTANTS.WBNB, pacoca]

    return isCAKEStaking
        ? {
            addresses,
            earnedToAUTOPath,

            earnedToToken0Path: [],
            earnedToToken1Path: [],

            token0ToEarnedPath: [],
            token1ToEarnedPath: [],
        }
        : {
            addresses,
            earnedToAUTOPath,

            earnedToToken0Path: tokenRouter({ fromToken: earnedToken, toToken: token0Address }),
            earnedToToken1Path: tokenRouter({ fromToken: earnedToken, toToken: token1Address }),

            token0ToEarnedPath: tokenRouter({ fromToken: token0Address, toToken: earnedToken }),
            token1ToEarnedPath: tokenRouter({ fromToken: token1Address, toToken: earnedToken }),
        }
}
