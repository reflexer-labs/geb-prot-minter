pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebProtMinter.sol";

contract GebProtMinterTest is DSTest {
    GebProtMinter minter;

    function setUp() public {
        minter = new GebProtMinter();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
