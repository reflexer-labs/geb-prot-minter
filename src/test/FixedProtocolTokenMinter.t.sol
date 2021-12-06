pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/delegate.sol";
import "geb-protocol-token-authority/ProtocolTokenAuthority.sol";

import {FixedProtocolTokenMinter} from "../FixedProtocolTokenMinter.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
    function roll(uint256) virtual public;
}

contract FixedProtocolTokenMinterTest is DSTest {
    Hevm hevm;

    DSDelegateToken          protocolToken;
    FixedProtocolTokenMinter minter;
    ProtocolTokenAuthority   authority;

    uint256 initialSupply        = 1000000E18;
    uint256 amountToMintPerWeek  = 4200E18;
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

    function test_setup() public {
        assertEq(minter.authorizedAccounts(address(this)), 1);
        assertTrue(minter.initialMintReceiver() == initialTokenReceiver);
        assertTrue(minter.terminalMintReceiver() == terminalTokenReceiver);
        assertTrue(address(minter.protocolToken()) == address(protocolToken));
        assertEq(minter.mintStartTime(), mintStartTime);
        assertEq(minter.initialAmountToMintPerWeek(), amountToMintPerWeek);
    }
    function testFail_mint_before_start() public {
        minter.mint();
    }
    function test_mint_first() public {
        hevm.warp(now + 1 weeks + 1);
        minter.mint();

        assertEq(protocolToken.balanceOf(address(minter)), amountToMintPerWeek);
        assertEq(minter.lastWeeklyMint(), now);
        assertEq(minter.lastTaggedWeek(), 1);
    }
    function testFail_second_mint_before_week_passes() public {
        hevm.warp(now + 1 weeks + 1);
        minter.mint();

        hevm.warp(now + 2 days);
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
    function test_first_mint_long_after_start() public {
        hevm.warp(now + 52 weeks + 1);
        minter.mint();

        hevm.warp(now + 1 weeks);
        minter.mint();

        assertEq(protocolToken.balanceOf(address(minter)), amountToMintPerWeek * 2);
        assertEq(minter.lastWeeklyMint(), now);
        assertEq(minter.lastTaggedWeek(), 2);
    }
    function test_wait_multi_weeks_before_minting() public {
        hevm.warp(now + 1 weeks + 1);
        minter.mint();

        hevm.warp(now + 3 weeks);
        minter.mint();
        minter.mint();
        minter.mint();

        assertEq(protocolToken.balanceOf(address(minter)), amountToMintPerWeek * 4);
        assertEq(minter.lastWeeklyMint(), now);
        assertEq(minter.lastTaggedWeek(), 4);
    }
    function test_mint_full_initial_period() public {
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < minter.INITIAL_INFLATION_PERIOD(); i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);
        }

        assertEq(protocolToken.balanceOf(address(minter)), minter.INITIAL_INFLATION_PERIOD() * amountToMintPerWeek);
        assertEq(minter.lastWeeklyMint(), now - 1 weeks);
        assertEq(minter.lastTaggedWeek(), minter.INITIAL_INFLATION_PERIOD());

        assertEq(protocolToken.totalSupply(), initialSupply + minter.INITIAL_INFLATION_PERIOD() * amountToMintPerWeek);
    }
    function testFail_mint_full_initial_period_mint_terminal_not_enough_delay() public {
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < 51; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);

        }
        minter.mint();

        hevm.warp(now + 1);
        minter.mint();
    }
    function test_mint_terminal() public {
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < 51; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);
        }
        minter.mint();

        hevm.warp(now + 1 weeks);
        minter.mint();

        assertEq(minter.lastTerminalYearStart(), minter.INITIAL_INFLATION_PERIOD());
        assertEq(minter.terminalYearStartTokenAmount(), minter.INITIAL_INFLATION_PERIOD() * amountToMintPerWeek + initialSupply);
    }
    function test_mint_terminal_full_year() public {
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < 51; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);
        }
        minter.mint();

        uint256 preTerminalSupply = protocolToken.totalSupply();

        hevm.warp(now + 1 weeks);
        for (uint i = 0; i < 51; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);
        }
        minter.mint();

        assertEq(protocolToken.totalSupply(), 1242767999999999999999968);
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
              assertEq(minter.terminalYearStartTokenAmount(), 1242767999999999999999968);
            }
        }
        minter.mint();

        assertEq(protocolToken.totalSupply(), 1267623359999999999999952);
    }
    function test_transfer_all_minted_initial_minter() public {
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < minter.INITIAL_INFLATION_PERIOD(); i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);
            minter.transferMintedAmount(protocolToken.balanceOf(address(minter)));
        }

        assertEq(protocolToken.balanceOf(address(minter)), 0);
        assertEq(protocolToken.balanceOf(initialTokenReceiver), minter.INITIAL_INFLATION_PERIOD() * amountToMintPerWeek);
        assertEq(protocolToken.balanceOf(terminalTokenReceiver), 0);
    }
    function test_transfer_all_minted_both_minters() public {
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < minter.INITIAL_INFLATION_PERIOD(); i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);
            minter.transferMintedAmount(protocolToken.balanceOf(address(minter)));
        }

        for (uint i = 0; i < minter.INITIAL_INFLATION_PERIOD(); i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);
            minter.transferMintedAmount(protocolToken.balanceOf(address(minter)));
        }

        assertEq(protocolToken.balanceOf(address(minter)), 0);
        assertEq(protocolToken.balanceOf(initialTokenReceiver), minter.INITIAL_INFLATION_PERIOD() * amountToMintPerWeek);
        assertTrue((initialSupply + minter.INITIAL_INFLATION_PERIOD() * amountToMintPerWeek) * 2 / 100 - protocolToken.balanceOf(terminalTokenReceiver) < 1E18);
    }
}
