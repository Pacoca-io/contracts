const CONSTANTS = require('./constants')

module.exports = ({ fromToken, toToken }) => {
    fromToken = fromToken.toLowerCase()
    toToken = toToken.toLowerCase()

    if (fromToken === toToken)
        return []

    if (fromToken === CONSTANTS.WBNB || toToken === CONSTANTS.WBNB)
        return [fromToken, toToken]

    return [fromToken, CONSTANTS.WBNB, toToken]
}
