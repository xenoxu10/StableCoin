// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Test} from "lib/forge-std/src/Test.sol";
import{DSC} from "../src/DSC.sol";
import {DSCengine} from "../src/DSCengine.sol";
import {deployDSC} from "../script/DeployDSC.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockFailedTransfer} from "../src/MockTransferFailed.sol";

import {MockV3AggregatorWETH} from "../src/MockbtcAggregator.sol";
import {MockFailedMintDSC} from "./Mocks/MockMintFailedDSC.sol";


contract DSCEngineTest is Test {
   deployDSC dpDSC;
   DSCengine dscengine;
   DSC dsc;
   address weth;
   address ethUsd;
   address btcUsd;
    address public wbtc;
    uint256 public deployerKey;

    address public user = address(1);

     uint private Starting_Amount=10 ether;
     uint private AMOUNT=1 ether;
     uint private DSCmintedAmount=2 ether;

   address[] tokenAddress;
   address[] pricefeedAddress;

      function setUp() public{
        dpDSC=new deployDSC();
        HelperConfig config=new HelperConfig();
        (dsc,dscengine,config)=dpDSC.run();
        ( ethUsd,btcUsd, weth, wbtc,deployerKey)=config.activeNetworkConfig();
         if (block.chainid == 31337) {
            vm.deal(user, Starting_Amount);
        }
        ERC20Mock(weth).mint(user, Starting_Amount); 
         ERC20Mock(wbtc).mint(user, Starting_Amount);
        
          
    }

    function testTokenAddressesAndPriceFeedAddressesAmountsDontMatch() public {
        tokenAddress.push(weth);
         
        pricefeedAddress.push(ethUsd);
        pricefeedAddress.push(btcUsd);
        vm.expectRevert(DSCengine.DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        dscengine=new DSCengine(tokenAddress,pricefeedAddress,address(dsc));
    }


    function testgetUSDvalue() public{
        uint expectedamount=dscengine.getUSDvalue(weth, AMOUNT);
        uint amount=AMOUNT*2000;
        assertEq(expectedamount, amount);
    }

    function testgetAccountInfo() public
    {
        (uint a,uint b)=dscengine.getAccountInfo(user);
        assertEq(a,0);
        assertEq(b,0);
    }

    function testmoreThanzero() public{
        vm.expectRevert(DSCengine.DSCEngine__NeedsMoreThanZero.selector);
        vm.startPrank(user);
        ERC20Mock(weth).mint(user, Starting_Amount);
        ERC20Mock(weth).approve(user,1 ether);
        dscengine.depositCollateral(weth, 1);
    }

    function testdepositCollateral() public{
        vm.startPrank(user);
        ERC20Mock(weth).mint(user, Starting_Amount);
        ERC20Mock(weth).approve(user,1 ether);
        dscengine.depositCollateral(weth, 1);
    }
    function testtokenAddr() public
    {
        vm.startPrank(user);
        
        ERC20Mock erc=new ERC20Mock();
        erc.mint(user, Starting_Amount);
        erc.approve(user, 1 ether);
       vm.expectRevert(abi.encodeWithSelector(DSCengine.DSCEngine__TokenNotAllowed.selector, address(erc)));
        dscengine.depositCollateral(address(erc), 1 ether);
    }
    modifier depositedCollateral(){
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscengine),2 ether);
        dscengine.depositCollateral(weth, 1 ether);
        vm.stopPrank();
        _;

    }

     function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

     function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral{
          (uint _totalDSCminted,uint _totalCollateralvalue)=dscengine.getAccountInfo(user);
           uint256 expectedDepositedAmount = dscengine.getTokenAmountfromUSD(weth, _totalCollateralvalue);
          assertEq(_totalDSCminted,0);
          assertEq(1 ether,expectedDepositedAmount);
     }
//Receck

//mint DSC
      function testRevertsIfMintFails() public{
         MockFailedMintDSC mockDsc = new MockFailedMintDSC();
         tokenAddress=[weth];
         pricefeedAddress=[ethUsd];
         address owner=msg.sender;
         vm.prank(owner);
         DSCengine mockdsce=new DSCengine(tokenAddress,pricefeedAddress,address(mockDsc));
         mockDsc.transferOwnership(address(mockdsce));
         
         vm.startPrank(user);
         ERC20Mock(weth).approve(address(mockdsce),AMOUNT);
         vm.expectRevert(DSCengine.DSCEngine__MintFailed.selector);
          mockdsce.depositCollateralandmintDSC(weth, AMOUNT, 1);

      }

       function testRevertsIfMintAmountIsZero() public
       {vm.startPrank(user);
       ERC20Mock(weth).approve(address(dscengine),AMOUNT);
       dscengine.depositCollateralandmintDSC(weth, AMOUNT, 1);
        vm.expectRevert(DSCengine.DSCEngine__NeedsMoreThanZero.selector);
        dscengine.mint(0);
        vm.stopPrank();
       }

       function testRevertsIfMintAmountBreaksHealthFactor() public{
       
        (, int256 answer, ,, )= MockV3AggregatorWETH(ethUsd).latestRoundData();
         uint amountToMint = (AMOUNT * (uint256(answer) * dscengine.get_Additional_Price_Precession())) / dscengine.get_divide_precession();
         vm.startPrank(user);
         ERC20Mock(weth).approve(address(dscengine),AMOUNT);

        }


       function testCanMintDsc() public depositedCollateral{
        vm.startPrank(user);
        dscengine.mint(2);
        uint dscAmount=dsc.balanceOf(user);
        assertEq(2,dscAmount);
       }

       //burn dsc

       function testRevertsIfBurnAmountIsZero() public{
        vm.startPrank(user);
        vm.expectRevert(DSCengine.DSCEngine__NeedsMoreThanZero.selector);
        dscengine.burnDSC(0);
        vm.stopPrank();
       }

       function testCantBurnMoreThanUserHas() public{
        vm.prank(user);
        vm.expectRevert();
        dscengine.burnDSC(1);
       }

       modifier depositCollateralandMintDSC{
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscengine),Starting_Amount);
        dscengine.depositCollateralandmintDSC(weth, Starting_Amount,DSCmintedAmount);
        vm.stopPrank();
        _;
       }

        function testCanBurnDsc() depositCollateralandMintDSC public
        {
            vm.startPrank(user);
            dsc.approve(address(dscengine),DSCmintedAmount);
            dscengine.burnDSC(DSCmintedAmount);
           
           
             vm.stopPrank();
              uint userbalance=dsc.balanceOf(user);
            assertEq(userbalance,0);


        }

   
   


}