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
    uint256 weeklyMintDecay     = 0.97E18;
    uint256 mintStartTime;

    uint256 WAD = 1E18;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        protocolToken = new DSDelegateToken("PROT", "PROT");
        authority     = new ProtocolTokenAuthority();

        mintStartTime = now + 1 weeks;

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
    function testFail_mint_before_start() public {
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

        uint256 minted      = amountToMintPerWeek;
        amountToMintPerWeek = amountToMintPerWeek * weeklyMintDecay / WAD;

        hevm.warp(now + 1 weeks);
        minter.mint();

        assertEq(protocolToken.balanceOf(address(minter)), minted + amountToMintPerWeek);
        assertTrue(minter.amountToMintPerWeek() < amountToMintPerWeek);
        assertEq(minter.amountToMintPerWeek(), amountToMintPerWeek * weeklyMintDecay / WAD);
        assertEq(minter.lastWeeklyMint(), now);
        assertEq(minter.lastTaggedWeek(), 2);
    }
    function test_first_mint_long_after_start() public {
        hevm.warp(now + 52 weeks + 1);
        minter.mint();

        uint256 minted      = amountToMintPerWeek;
        amountToMintPerWeek = amountToMintPerWeek * weeklyMintDecay / WAD;

        hevm.warp(now + 1 weeks);
        minter.mint();

        assertEq(protocolToken.balanceOf(address(minter)), minted + amountToMintPerWeek);
        assertTrue(minter.amountToMintPerWeek() < amountToMintPerWeek);
        assertEq(minter.amountToMintPerWeek(), amountToMintPerWeek * weeklyMintDecay / WAD);
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

        for (uint i = 0; i < 4; i++) {
            amountToMintPerWeek = amountToMintPerWeek * weeklyMintDecay / WAD;
        }

        assertTrue(protocolToken.balanceOf(address(minter)) > 0);
        assertEq(minter.amountToMintPerWeek(), amountToMintPerWeek);
        assertEq(minter.lastWeeklyMint(), now);
        assertEq(minter.lastTaggedWeek(), 4);
    }
    function test_mint_full_initial_period() public {
        uint256 totalMinted;
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < 52; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);

            amountToMintPerWeek = amountToMintPerWeek * weeklyMintDecay / WAD;
        }

        assertTrue(protocolToken.balanceOf(address(minter)) > 0);
        assertEq(minter.amountToMintPerWeek(), amountToMintPerWeek);
        assertEq(minter.lastWeeklyMint(), now - 1 weeks);
        assertEq(minter.lastTaggedWeek(), 52);
    }
    function testFail_mint_full_initial_period_mint_terminal() public {
        uint256 totalMinted;
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < 51; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);

            amountToMintPerWeek = amountToMintPerWeek * weeklyMintDecay / WAD;
        }
        minter.mint();

        hevm.warp(now + 1);
        minter.mint();
    }
    function test_mint_terminal_once() public {
        uint256 totalMinted;
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < 51; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);

            amountToMintPerWeek = amountToMintPerWeek * weeklyMintDecay / WAD;
        }
        minter.mint();

        hevm.warp(now + 1 weeks);
        minter.mint();
    }
    function test_mint_three_times_initial_period() public {
        uint256 totalMinted;
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < 156; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);

            totalMinted = totalMinted + amountToMintPerWeek;
            amountToMintPerWeek = amountToMintPerWeek * weeklyMintDecay / WAD;
        }

        assertEq(protocolToken.balanceOf(address(minter)), totalMinted);
        assertTrue(amountToMintPerWeek > 0);
        assertEq(minter.amountToMintPerWeek(), amountToMintPerWeek);
        assertEq(minter.lastWeeklyMint(), now - 1 weeks);
        assertEq(minter.lastTaggedWeek(), 156);
    }
    function test_transfer_all_minted() public {
        uint256 totalMinted;
        hevm.warp(now + 1 weeks + 1);

        for (uint i = 0; i < 156; i++) {
            minter.mint();
            hevm.warp(now + 1 weeks);

            totalMinted = totalMinted + amountToMintPerWeek;
            minter.transferMintedAmount(protocolToken.balanceOf(address(minter)));
            amountToMintPerWeek = amountToMintPerWeek * weeklyMintDecay / WAD;
        }

        assertEq(protocolToken.balanceOf(address(minter)), 0);
        assertEq(protocolToken.balanceOf(address(0x1)), totalMinted);
    }
}
