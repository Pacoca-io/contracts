import "../access/ControlledUUPS.sol";

contract AuthorityTest is ControlledUUPS {
    event Called(string);

    function initialize(address _authority) public initializer {
        __ControlledUUPS_init(_authority);
    }

    function onlyOwner() public requireRole(IAuthority.Role.OWNER) {
        emit Called('onlyOwner');
    }

    function onlyDao() public requireRole(IAuthority.Role.DAO) {
        emit Called('onlyDao');
    }

    function onlyTreasury() public requireRole(IAuthority.Role.TREASURY) {
        emit Called('onlyTreasury');
    }

    function onlyManager() public requireRole(IAuthority.Role.MANAGER) {
        emit Called('onlyManager');
    }

    function onlyKeeper() public requireRole(IAuthority.Role.KEEPER) {
        emit Called('onlyKeeper');
    }

    function onlyRewardDistributor() public requireRole(IAuthority.Role.REWARD_DISTRIBUTOR) {
        emit Called('onlyRewardDistributor');
    }
}
