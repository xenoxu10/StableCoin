//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20, ERC20Burnable, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DSC} from "./DSC.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCengine {
    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();


    DSC private immutable dsc;

    mapping(address => address) private s_priceFeeds;
    mapping(address => mapping(address => uint256)) private collateral;
    mapping(address => uint256) private DSCmintedAmount;

    uint256 private constant ADDITIONAL_PRICE_PRECESSION = 1e10;
    uint256 private constant DIVIDE_PRECESSION = 1e18;
    uint256 private constant PRECESSION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECESSION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant LIQUIDATION_BONUS=10;

    address[] private collateralTokens;

    modifier morethanZero(uint256 amount) {
        if(amount==0)
        {
             revert DSCEngine__NeedsMoreThanZero();
        }
       
        _;
    }

    modifier istokenAllowed(address tokenAddress) {
        if(s_priceFeeds[tokenAddress] == address(0))
        {
             revert DSCEngine__TokenNotAllowed(tokenAddress);
        }
        _;
    }

    constructor(address[] memory tokenAddress, address[] memory pricefeedAddress, address _DSC) {
        if(tokenAddress.length != pricefeedAddress.length)
        {
             revert DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = pricefeedAddress[i];
            collateralTokens.push(tokenAddress[i]);
        }
        dsc = DSC(_DSC);
    }

    function depositCollateralandmintDSC(address _tokenCollateralAddress, uint256 _collateralAmount,uint256 DSCamount ) external {
        depositCollateral( _tokenCollateralAddress,  _collateralAmount);
        mint( DSCamount);

    }

    // CAreful Reentrancy Attack!  checked!
    function depositCollateral(address _tokenCollateralAddress, uint256 _collateralAmount)
        public 
        morethanZero(_collateralAmount)
        istokenAllowed(_tokenCollateralAddress)
    {
        collateral[msg.sender][_tokenCollateralAddress] += _collateralAmount;

        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _collateralAmount);
        if(!success)
        {
             revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDSC(address tokenCollateralAddress,uint collateralAmount,uint DSCamount) external {
        redeem( tokenCollateralAddress, collateralAmount);
        burnDSC(DSCamount);
        _revertIfHealthFactorisBroken(msg.sender);

    }
//checked
    function redeem(address tokenCollateralAddress,uint collateralAmount) public  morethanZero(collateralAmount) {
         _redeemCollateral(tokenCollateralAddress,collateralAmount,msg.sender,msg.sender);
       
    }

    function mint(uint256 DSCamount) public morethanZero(DSCamount)  {
        DSCmintedAmount[msg.sender] += DSCamount;
        _revertIfHealthFactorisBroken(msg.sender);
        bool minted = dsc.mint(msg.sender, DSCamount);
        if(!minted)
        {
             revert DSCEngine__MintFailed();
        }
    }

    function burnDSC(uint DSCamount) morethanZero(DSCamount) public {
         _revertIfHealthFactorisBroken(msg.sender);
        _burnDSC(DSCamount,msg.sender,msg.sender);
         
    }

    function liquidate(address collateralToken,address user, uint debtToCover) external {
        uint healthfactor=_getHealthFactor(user);
        if(healthfactor<=MIN_HEALTH_FACTOR)
        {
             
            revert DSCEngine__HealthFactorOk();
        }
        uint tokenAmount=getTokenAmountfromUSD(collateralToken,debtToCover);
        uint bonus=(tokenAmount*LIQUIDATION_BONUS)/LIQUIDATION_PRECESSION;
        uint totalCollateral=tokenAmount+bonus;
        _redeemCollateral(collateralToken,totalCollateral,user,msg.sender);
        _burnDSC(debtToCover,user,msg.sender);
         _revertIfHealthFactorisBroken(msg.sender);

    }

    function healthFactor() external {}

    function getTokenAmountfromUSD(address collateralToken, uint usdAmount) public view returns(uint){
         AggregatorV3Interface pricefeed = AggregatorV3Interface(s_priceFeeds[collateralToken]);
        (, int256 price,,,) = pricefeed.latestRoundData();
        //2000/ETH amount/2000
        return (uint(usdAmount)*uint(PRECESSION))/(uint(price)*ADDITIONAL_PRICE_PRECESSION);

    }

    function getCollateralValue(address user) public view returns (uint256) {
        uint256 totalCollateralValueInUSD = 0;

        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 collateralAmount = collateral[user][token];
            totalCollateralValueInUSD += getUSDvalue(token, collateralAmount);
        }
        return totalCollateralValueInUSD;
    }


    function getAccountInfo(address user) public view returns (uint256, uint256){
        return(_getAccountInfo( user));
    }

//checked
    function getUSDvalue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface pricefeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = pricefeed.latestRoundData();
        uint256 amountInUSD = (uint256(price) * ADDITIONAL_PRICE_PRECESSION * amount) / DIVIDE_PRECESSION;
        return amountInUSD;
    }

    //private functions

    function _burnDSC(uint amount,address onbehalfOf,address DSCfrom) internal
    {
         DSCmintedAmount[onbehalfOf]-=amount;
         bool success=dsc.transferFrom(DSCfrom,address(this),amount);
         if(!success)
         {
             revert DSCEngine__TransferFailed();
         }
         dsc.burn(amount);
     

    }

    function  _redeemCollateral( address tokenCollateralAddress,uint collateralAmount,address from,address to) internal {
          collateral[from][tokenCollateralAddress]-=collateralAmount;
        bool success=IERC20(tokenCollateralAddress).transfer(to,collateralAmount);
        if(!success)
        {
             revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorisBroken(msg.sender);
    }

    function _getAccountInfo(address user) private view returns (uint256, uint256) {
        uint256 _totalDSCminted = DSCmintedAmount[user];
        uint256 _totalCollateralvalue = getCollateralValue(user);
        return (_totalDSCminted, _totalCollateralvalue);
    }

    function _getHealthFactor(address user) private view returns (uint256) {
        //total colateral value
        //total DSC
        (uint256 totalDSCminted, uint256 collateralValue) = _getAccountInfo(user);
        return (collateralValue * LIQUIDATION_THRESHOLD) / (LIQUIDATION_PRECESSION * totalDSCminted);
    }

    function _revertIfHealthFactorisBroken(address user) private view {
        uint256 _healthFactor = _getHealthFactor(user);
        if(_healthFactor < MIN_HEALTH_FACTOR)
        {
             revert DSCEngine__BreaksHealthFactor(_healthFactor);
        }
    }
    

    //constant returning function

    function get_Additional_Price_Precession() public pure returns(uint)
    {
        return ADDITIONAL_PRICE_PRECESSION;
    }

    function get_divide_precession() public pure returns(uint)
    {
        return DIVIDE_PRECESSION;
    }

    function DSCmintedbyUSER(address user) public view returns(uint)
    {
        return DSCmintedAmount[user];
    }
}
