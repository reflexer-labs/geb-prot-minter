pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/delegate.sol";

import {DistroDualSplit} from "./DistroDualSplit.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
    function roll(uint256) virtual public;
}

contract DistroDualSplitTest is DSTest {
    Hevm hevm;

    DSDelegateToken protocolToken;
    DistroDualSplit splitter;

    address alice           = address(0x1);
    address bob             = address(0x2);

    uint256 aliceAllocation = 35;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        protocolToken = new DSDelegateToken("PROT", "PROT");
        splitter      = new DistroDualSplit(address(protocolToken), alice, bob, aliceAllocation);
        protocolToken.mint(address(splitter), 100 ether);
    }

    function test_setup() public {
        assertTrue(address(splitter.token()) == address(protocolToken));

        (address who, uint256 allocation) = splitter.firstReceiver();
        assertTrue(who == alice);
        assertEq(allocation, aliceAllocation);

        (who, allocation) = splitter.secondReceiver();
        assertTrue(who == bob);
        assertEq(allocation, 100 - aliceAllocation);
    }
    function test_split() public {
        splitter.distribute();

        assertEq(protocolToken.balanceOf(address(splitter)), 0);
        assertEq(protocolToken.balanceOf(address(alice)), 35 ether);
        assertEq(protocolToken.balanceOf(address(bob)), 65 ether);
    }
    function test_split_twice() public {
        splitter.distribute();
        protocolToken.mint(address(splitter), 100.123456789 ether);
        splitter.distribute();

        assertEq(protocolToken.balanceOf(address(splitter)), 0);
        assertEq(protocolToken.balanceOf(address(alice)), 70043209876150000000);
        assertEq(protocolToken.balanceOf(address(bob)), 130080246912850000000);
    }
}
