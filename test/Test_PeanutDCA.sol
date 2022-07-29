import "../PeanutDCA.sol";

contract Test_PeanutDCA is PeanutDCA {
    function deltaAt(uint _pid, uint _swapOffset) external view returns (uint) {
        return _poolDelta[_pid][_swapOffset];
    }

    function poolPath(uint _pid) external view returns (address[] memory) {
        return poolInfo[_pid].path;
    }
}
