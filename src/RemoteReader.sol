pragma solidity ^0.8.25;

// REMOTESTATICCALL precompile (addr 0x0101)
address constant RSC_PRECOMPILE = address(
    0x0000000000000000000000000000000000000101
);

// L1SLOAD precompile (addr 0x0102)
address constant L1SLOAD_PRECOMPILE = address(
    0x0000000000000000000000000000000000000102
);

contract RemoteReader {
    event ReadByRSC(uint256 value);
    event ReadByL1SLOAD(uint256 value);

    function readCountRSC(address l1Counter) external {
        // calldata for L1Counter.count()
        bytes memory inner = abi.encodeWithSelector(
            bytes4(keccak256("count()"))
        );
        // calldata for the precompile
        bytes memory payload = abi.encode(l1Counter, inner);

        (bool ok, bytes memory ret) = RSC_PRECOMPILE.staticcall(payload);
        require(ok, "remote static call failed");

        uint256 v = abi.decode(ret, (uint256));
        emit ReadByRSC(v);
    }

    function readCountL1SLOAD(address l1Counter) external {
        bytes32 slot0 = bytes32(uint256(0));
        (bool ok, bytes memory ret) = L1SLOAD_PRECOMPILE.staticcall(
            abi.encode(l1Counter, slot0)
        );
        require(ok, "precompile failed");

        uint256 v = abi.decode(ret, (uint256));
        emit ReadByL1SLOAD(v);
    }
}
