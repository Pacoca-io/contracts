import "./ControlledUUPSUpgraded.sol";

contract AuthorityTestUpgraded is ControlledUUPSUpgraded {
    event Called(string);

    function initialize(address _authority) public initializer {
        __ControlledUUPS_init(_authority);
    }

    function onlyOwner() public requireRole(IAuthorityUpgraded.Role.OWNER) {
        emit Called('onlyOwner');
    }

    function onlyDao() public requireRole(IAuthorityUpgraded.Role.DAO) {
        emit Called('onlyDao');
    }

    function onlyTreasury() public requireRole(IAuthorityUpgraded.Role.TREASURY) {
        emit Called('onlyTreasury');
    }

    function onlyManager() public requireRole(IAuthorityUpgraded.Role.MANAGER) {
        emit Called('onlyManager');
    }

    function onlyKeeper() public requireRole(IAuthorityUpgraded.Role.KEEPER) {
        emit Called('onlyKeeper');
    }

    function onlyRewardDistributor() public requireRole(IAuthorityUpgraded.Role.REWARD_DISTRIBUTOR) {
        emit Called('onlyRewardDistributor');
    }

    function onlyTestRole() public requireRole(IAuthorityUpgraded.Role.TEST_ROLE) {
        emit Called('onlyTestRole');
    }
}
