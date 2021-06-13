pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/delegate.sol";
import "geb-protocol-token-authority/ProtocolTokenAuthority.sol";

import {ProtocolTokenMinter} from "./ProtocolTokenMinter.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
    function roll(uint256) virtual public;
}

contract ProtocolTokenMinterTest is DSTest {
    Hevm hevm;

    DSDelegateToken        protocolToken;
    ProtocolTokenMinter    minter;
    ProtocolTokenAuthority authority;

    uint256 initialSupply       = 1000000E18;
    uint256 amountToMintPerWeek = 9615E18;       // Annualized this is about 500K tokens
    uint256 weeklyMintDecay     = 0.98E18;
    uint256 mintStartTime       = now + 1 weeks;

    uint256 WAD = 10E18;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        protocolToken = new DSDelegateToken("PROT", "PROT");
        authority     = new ProtocolTokenAuthority();

        protocolToken.mint(address(this), initialSupply);
        protocolToken.setAuthority(DSAuthority(address(authority)));
        protocolToken.setOwner(address(0));

        minter = new ProtocolTokenMinter(
          address(0x1),
          address(protocolToken),
          mintStartTime,
          amountToMintPerWeek,
          weeklyMintDecay
        );

        authority.setOwner(address(minter));
    }

    function test_setup() public {
      assertEq(minter.authorizedAccounts(address(this)), 1);
      assertTrue(minter.mintReceiver() == address(0x1));
      assertTrue(address(minter.protocolToken()) == address(protocolToken));
      assertEq(minter.mintStartTime(), mintStartTime);
      assertEq(minter.amountToMintPerWeek(), amountToMintPerWeek);
      assertEq(minter.weeklyMintDecay(), weeklyMintDecay);
    }
    /* function testFail_mint_before_start() public {
      minter.mint();
    }
    function test_mint_first() public {
      hevm.warp(now + 1 weeks + 1);
      minter.mint();

      assertEq(protocolToken.balanceOf(address(minter)), amountToMintPerWeek);
      assertTrue(minter.amountToMintPerWeek() < amountToMintPerWeek);
      assertEq(minter.amountToMintPerWeek(), amountToMintPerWeek * weeklyMintDecay / WAD);
      assertEq(minter.lastWeeklyMint(), now);
      assertEq(minter.lastTaggedWeek(), 1);
    } */


    /* function testFail_second_mint_before_week_passes() public {

    }
    function test_mint_twice() public {

    }
    function test_wait_multi_weeks_before_minting() public {

    }
    function test_mint_full_initial_period() public {

    }
    function testFail_mint_full_initial_period_mint_terminal() public {

    }
    function test_mint_three_times_initial_period() public {

    } */
}
