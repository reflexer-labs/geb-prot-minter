pragma solidity 0.6.7;

import "./GebMath.sol";

abstract contract DSTokenLike {
    function totalSupply() virtual public view returns (uint256);
    function mint(address, uint256) virtual public;
    function transfer(address, uint256) virtual public;
}

contract DecreasingProtocolTokenMinter is GebMath {
    // --- Auth ---
    mapping (address => uint256) public authorizedAccounts;
    /**
     * @notice Add auth to an account
     * @param account Account to add auth to
     */
    function addAuthorization(address account) external isAuthorized {
        authorizedAccounts[account] = 1;
        emit AddAuthorization(account);
    }
    /**
     * @notice Remove auth from an account
     * @param account Account to remove auth from
     */
    function removeAuthorization(address account) external isAuthorized {
        authorizedAccounts[account] = 0;
        emit RemoveAuthorization(account);
    }
    /**
    * @notice Checks whether msg.sender can call an authed function
    **/
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "DecreasingProtocolTokenMinter/account-not-authorized");
        _;
    }

    // --- Variables ---
    // Current amount to mint per week
    uint256 public amountToMintPerWeek;                                   // wad
    // Last timestamp when the contract accrued inflation
    uint256 public lastWeeklyMint;                                        // timestamp
    // Last week number when the contract accrued inflation
    uint256 public lastTaggedWeek;
    // Decay for the weekly amount to mint
    uint256 public weeklyMintDecay;                                       // wad
    // Timestamp when minting starts
    uint256 public mintStartTime;
    // Whether minting is currently allowed
    uint256 public mintAllowed = 1;

    uint256 public constant WEEK                     = 1 weeks;
    uint256 public constant WEEKS_IN_YEAR            = 52;
    uint256 public constant INITIAL_INFLATION_PERIOD = WEEKS_IN_YEAR * 3; // 3 years
    uint256 public constant TERMINAL_INFLATION       = 1.02E18;           // 2% compounded weekly

    // Address that receives minted tokens
    address     public mintReceiver;

    // The token being minted
    DSTokenLike public protocolToken;

    // --- Events ---
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event Mint(uint256 weeklyAmount);
    event ModifyParameters(bytes32 parameter, address data);
    event ModifyParameters(bytes32 parameter, uint256 data);

    constructor(
      address mintReceiver_,
      address protocolToken_,
      uint256 mintStartTime_,
      uint256 amountToMintPerWeek_,
      uint256 weeklyMintDecay_
    ) public {
        require(mintReceiver_ != address(0), "DecreasingProtocolTokenMinter/null-mint-receiver");
        require(protocolToken_ != address(0), "DecreasingProtocolTokenMinter/null-prot-token");

        require(mintStartTime_ > now, "DecreasingProtocolTokenMinter/invalid-start-time");
        require(amountToMintPerWeek_ > 0, "DecreasingProtocolTokenMinter/null-amount-to-mint");
        require(weeklyMintDecay_ < WAD, "DecreasingProtocolTokenMinter/invalid-mint-decay");

        authorizedAccounts[msg.sender] = 1;

        mintReceiver        = mintReceiver_;
        protocolToken       = DSTokenLike(protocolToken_);
        mintStartTime       = mintStartTime_;
        amountToMintPerWeek = amountToMintPerWeek_;
        weeklyMintDecay     = weeklyMintDecay_;

        emit AddAuthorization(msg.sender);
    }

    // --- Administration ---
    /*
    * @notify Change the mintReceiver
    * @param parameter The parameter name
    * @param data The new address for the receiver
    */
    function modifyParameters(bytes32 parameter, address data) external isAuthorized {
        if (parameter == "mintReceiver") {
          mintReceiver = data;
        }
        else revert("DecreasingProtocolTokenMinter/modify-unrecognized-param");
        emit ModifyParameters(parameter, data);
    }
    /*
    * @notify Change mintAllowed
    * @param parameter The parameter name
    * @param data The new value for mintAllowed
    */
    function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
        if (parameter == "mintAllowed") {
          mintAllowed = data;
        }
        else revert("DecreasingProtocolTokenMinter/modify-unrecognized-param");
        emit ModifyParameters(parameter, data);
    }

    // --- Core Logic ---
    /*
    * @notice Mint tokens for this contract
    */
    function mint() external {
        require(now > mintStartTime, "DecreasingProtocolTokenMinter/too-early");
        require(mintAllowed == 1, "DecreasingProtocolTokenMinter/mint-not-allowed");
        require(addition(lastWeeklyMint, WEEK) <= now, "DecreasingProtocolTokenMinter/week-not-elapsed");

        uint256 weeklyAmount;
        lastWeeklyMint = (lastWeeklyMint == 0) ? now : addition(lastWeeklyMint, WEEK);

        if (lastTaggedWeek < INITIAL_INFLATION_PERIOD) {
          weeklyAmount        = amountToMintPerWeek;
          amountToMintPerWeek = multiply(amountToMintPerWeek, weeklyMintDecay) / WAD;
        } else {
          weeklyAmount = wdivide(protocolToken.totalSupply(), TERMINAL_INFLATION) / WEEKS_IN_YEAR;
        }

        lastTaggedWeek = addition(lastTaggedWeek, 1);

        protocolToken.mint(address(this), weeklyAmount);

        emit Mint(weeklyAmount);
      }

    /*
    * @notice Transfer minted tokens
    * @param amount The amount to transfer
    */
    function transferMintedAmount(uint256 amount) external isAuthorized {
        protocolToken.transfer(mintReceiver, amount);
    }
}
