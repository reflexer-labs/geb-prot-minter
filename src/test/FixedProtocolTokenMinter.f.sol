pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/delegate.sol";
import "geb-protocol-token-authority/ProtocolTokenAuthority.sol";

import {FixedProtocolTokenMinter} from "../FixedProtocolTokenMinter.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
    function roll(uint256) virtual public;
}

contract FixedProtocolTokenMinterFuzz is DSTest {
    Hevm hevm;

    DSDelegateToken          protocolToken;
    FixedProtocolTokenMinter minter;
    ProtocolTokenAuthority   authority;

    uint256 initialSupply        = 1000000E18;
    uint256 amountToMintPerWeek  = 3076.92 ether; // to be used in prod
    uint256 mintStartTime;

    address initialTokenReceiver  = address(0x123);
    address terminalTokenReceiver = address(0x987);

    uint256 WAD = 1E18;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        mintStartTime = now + 1 weeks;

        protocolToken = new DSDelegateToken("PROT", "PROT");
        authority     = new ProtocolTokenAuthority();

        protocolToken.mint(address(this), initialSupply);
        protocolToken.setAuthority(DSAuthority(address(authority)));
        protocolToken.setOwner(address(0));

        minter = new FixedProtocolTokenMinter(
          initialTokenReceiver,
          terminalTokenReceiver,
          address(protocolToken),
          mintStartTime,
          amountToMintPerWeek
        );

        authority.setOwner(address(minter));
    }

    function range(uint x, uint lower, uint upper) internal returns (uint) {
        require(upper > lower);
        return (x % (upper - lower)) + lower;
    }

    function test_setup() public {
        assertEq(minter.authorizedAccounts(address(this)), 1);
        assertTrue(minter.initialMintReceiver() == initialTokenReceiver);
        assertTrue(minter.terminalMintReceiver() == terminalTokenReceiver);
        assertTrue(address(minter.protocolToken()) == address(protocolToken));
        assertEq(minter.mintStartTime(), mintStartTime);
        assertEq(minter.initialAmountToMintPerWeek(), amountToMintPerWeek);
    }
    function testFail_mint_before_start(uint warp) public {
        hevm.warp(now + range(warp, 0, 1 weeks));
        minter.mint();
    }
    function test_mint_first(uint warp) public {
        hevm.warp(now + range(warp, 1 weeks + 1, 100 weeks));
        minter.mint();

        assertEq(protocolToken.balanceOf(address(minter)), amountToMintPerWeek);
        assertEq(minter.lastWeeklyMint(), now);
        assertEq(minter.lastTaggedWeek(), 1);
    }
    function testFail_second_mint_before_week_passes(uint warp1, uint warp2) public {
        hevm.warp(now + range(warp1, 1 weeks + 1, 100 weeks)); // works
        minter.mint();

        hevm.warp(now + range(warp2, 0, 1 weeks)); // will cause it to fail
        minter.mint();
    }
    function test_mint_twice() public {
        hevm.warp(now + 1 weeks + 1);
        minter.mint();

        hevm.warp(now + 1 weeks);
        minter.mint();

        assertEq(protocolToken.balanceOf(address(minter)), amountToMintPerWeek * 2);
        assertEq(minter.lastWeeklyMint(), now);
        assertEq(minter.lastTaggedWeek(), 2);
    }
    function test_wait_multi_weeks_before_minting(uint weekCount) public {
        hevm.warp(now + 1 weeks + 1);
        minter.mint();
        uint initialMintTimestamp = now;

        weekCount = range(weekCount, 1, 52);

        hevm.warp(now + weekCount * 1 weeks);
        for (uint i = 0; i < weekCount; i++)
            minter.mint();

        assertEq(protocolToken.balanceOf(address(minter)), amountToMintPerWeek * (weekCount + 1));
        assertEq(minter.lastWeeklyMint(), initialMintTimestamp + (weekCount * 1 weeks));
        assertEq(minter.lastTaggedWeek(), weekCount + 1);
    }
    function test_mint_terminal_fuzz(uint terminalWeeks) public {
        hevm.warp(now + 1);

        uint256 supply = protocolToken.totalSupply();

        for (uint i = 0; i < 52; i++) {
            hevm.warp(now + 1 weeks);
            minter.mint();
            supply += amountToMintPerWeek;
        }

        terminalWeeks = range(terminalWeeks, 1, 520); // testing up to 10 years
        emit log_named_uint("actual input", terminalWeeks);

        for (uint256 i = 0; i < terminalWeeks; i++) {
            hevm.warp(now + 1 weeks);
            uint terminalYearStartTokenAmount = minter.terminalYearStartTokenAmount();
            minter.mint();
            supply += terminalYearStartTokenAmount * minter.TERMINAL_INFLATION() / 100 / 52;
        }

        assertEq(protocolToken.totalSupply(), supply);
    }

    function test_mint_terminal_two_full_years() public {
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < 51; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);
        }
        minter.mint();

        hevm.warp(now + 1 weeks);
        for (uint i = 0; i < 103; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);

            if (i == 52) {
              assertEq(minter.lastTerminalYearStart(), minter.INITIAL_INFLATION_PERIOD() + 52);
              assertEq(minter.terminalYearStartTokenAmount(), 1183199836799999999999968);
            }
        }
        minter.mint();

        assertEq(protocolToken.totalSupply(), 1206863833535999999999952);
    }
}
