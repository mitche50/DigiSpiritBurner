// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "src/DigiSpiritBurner.sol";
import "src/Adventure/DigiDaigaku.sol";
import 'src/Adventure/DigiDaigakuHeroes.sol';
import "src/Adventure/DigiDaigakuSpirits.sol";
import 'src/Adventure/HeroAdventure.sol';
import "src/Token/IWETH.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DigiSpiritBurnerTest is Test {
    using SafeMath for uint256;

    address testUser = 0x76b2F9CAA443812D88693b86AdD2800F5F535C51;
    address badUser = 0x822a02E58919233821f4a5Bd5EfF4a214cCAB7AC;
    uint16 testToken = 467;
    uint16 testToken2 = 575;
    uint256 testHeroFee = 1e18;

    DigiSpiritBurner burner;
    HeroAdventure adventure = HeroAdventure(0xE60fE8C4C60Fd97f939F5136cCeb7c41EaaA624d);
    DigiDaigaku genesisToken = DigiDaigaku(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9);
    DigiDaigakuHeroes heroToken = DigiDaigakuHeroes(0xA225632b2EBc32B9f4278fc8E3FE5C6f6496D970);
    DigiDaigakuSpirits spiritToken = DigiDaigakuSpirits(0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973);

    address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWETH weth = IWETH(wethAddress);

    function setUp() public {
        burner = new DigiSpiritBurner();
        deal(wethAddress, testUser, 10e18);
        deal(wethAddress, badUser, 10e18);
    }


    function testSpiritDeposit() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);

        assert(spiritToken.ownerOf(testToken) == address(burner));

        vm.stopPrank();
    }

    function testSpiritWithdrawal() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);

        assert(spiritToken.ownerOf(testToken) == address(burner));

        burner.withdrawSpirit(testToken);

        assert(spiritToken.ownerOf(testToken) == testUser);

        vm.stopPrank();
    }

    function testSpiritWithdrawalNotOwner() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);

        assert(spiritToken.ownerOf(testToken) == address(burner));

        vm.stopPrank();

        vm.startPrank(badUser);

        vm.expectRevert(bytes("Not original owner of spirit"));
        burner.withdrawSpirit(testToken);

        vm.stopPrank();
    }

    function testEnterHeroQuest() public {
        vm.startPrank(testUser);

        weth.approve(address(burner), testHeroFee);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);
        assert(spiritToken.ownerOf(testToken) == address(burner));

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, testHeroFee);
        assert(genesisToken.ownerOf(testToken) == address(burner));

        burner.enterHeroQuest(testToken, testToken);
        vm.stopPrank();
    }

    function testRageQuit() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);
        
        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, testHeroFee);

        weth.approve(address(burner), testHeroFee);

        burner.enterHeroQuest(testToken, testToken);

        uint256 beforeQuitBalance = weth.balanceOf(testUser);
        uint256 beforeQuitClaimable = burner.getGenesisData(testToken).claimableRewards;

        burner.rageQuitHeroQuest(testToken);

        assert(weth.balanceOf(testUser) == beforeQuitBalance + (testHeroFee / 2));
        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeQuitClaimable + 
            (testHeroFee / 2) - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );

        vm.stopPrank();
    }

    // Confirms spirit holders cannot withdraw while they are on a quest
    // They will need to rageQuit or complete their quest to complete payment
    function testWithdrawWhileOnQuest() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);
        
        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, testHeroFee);

        weth.approve(address(burner), testHeroFee);

        burner.enterHeroQuest(testToken, testToken);

        vm.expectRevert(bytes("Mint or quit quest to withdraw"));
        burner.withdrawSpirit(testToken);

        vm.stopPrank();
    }

    function testMintHero() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);
        assert(spiritToken.ownerOf(testToken) == address(burner));

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);
        assert(genesisToken.ownerOf(testToken) == address(burner));

        weth.approve(address(burner), testHeroFee);

        burner.enterHeroQuest(testToken, testToken);
        vm.warp(block.timestamp + 1 days);

        uint256 beforeMintClaimable = burner.getGenesisData(testToken).claimableRewards;

        burner.mintHero(testToken);
        assert(heroToken.ownerOf(testToken) == testUser);

        // confirm claimableRewards increase for testUser
        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeMintClaimable + 
            testHeroFee - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );

        vm.stopPrank();
    }

    function testMultipleHeroMints() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);
        assert(spiritToken.ownerOf(testToken) == address(burner));

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);
        assert(genesisToken.ownerOf(testToken) == address(burner));

        weth.approve(address(burner), testHeroFee * 2);

        burner.enterHeroQuest(testToken, testToken);
        vm.warp(block.timestamp + 1 days);

        uint256 beforeMintClaimable = burner.getGenesisData(testToken).claimableRewards;

        burner.mintHero(testToken);
        assert(heroToken.ownerOf(testToken) == testUser);

        // confirm claimableRewards increase for testUser
        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeMintClaimable + 
            testHeroFee - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );

        spiritToken.approve(address(burner), testToken2);
        burner.depositSpirit(testToken2);

        assert(spiritToken.ownerOf(testToken2) == address(burner));
        burner.enterHeroQuest(testToken2, testToken);
        vm.warp(block.timestamp + 1 days);

        beforeMintClaimable = burner.getGenesisData(testToken).claimableRewards;
        burner.mintHero(testToken2);
        assert(heroToken.ownerOf(testToken) == testUser);

        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeMintClaimable + 
            testHeroFee - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );
    }

    function testHeroMintThenRageQuit() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);
        assert(spiritToken.ownerOf(testToken) == address(burner));

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);
        assert(genesisToken.ownerOf(testToken) == address(burner));

        weth.approve(address(burner), testHeroFee * 2);

        burner.enterHeroQuest(testToken, testToken);
        vm.warp(block.timestamp + 1 days);

        uint256 beforeMintClaimable = burner.getGenesisData(testToken).claimableRewards;

        burner.mintHero(testToken);
        assert(heroToken.ownerOf(testToken) == testUser);

        // confirm claimableRewards increase for testUser
        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeMintClaimable + 
            testHeroFee - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );

        spiritToken.approve(address(burner), testToken2);
        burner.depositSpirit(testToken2);

        assert(spiritToken.ownerOf(testToken2) == address(burner));
        burner.enterHeroQuest(testToken2, testToken);

        uint256 beforeQuitClaimable = burner.getGenesisData(testToken).claimableRewards;
        burner.rageQuitHeroQuest(testToken2);
        assert(spiritToken.ownerOf(testToken2) == testUser);

        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeQuitClaimable + 
            (testHeroFee / 2) - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );
    }

    function testRageQuitThenHeroMintDifferentToken() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken2);
        burner.depositSpirit(testToken2);

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);
        assert(genesisToken.ownerOf(testToken) == address(burner));

        weth.approve(address(burner), testHeroFee * 2);

        assert(spiritToken.ownerOf(testToken2) == address(burner));
        burner.enterHeroQuest(testToken2, testToken);

        uint256 beforeQuitClaimable = burner.getGenesisData(testToken).claimableRewards;
        burner.rageQuitHeroQuest(testToken2);
        assert(spiritToken.ownerOf(testToken2) == testUser);

        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeQuitClaimable + 
            (testHeroFee / 2) - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);
        assert(spiritToken.ownerOf(testToken) == address(burner));

        burner.enterHeroQuest(testToken, testToken);
        vm.warp(block.timestamp + 1 days);

        uint256 beforeMintClaimable = burner.getGenesisData(testToken).claimableRewards;

        burner.mintHero(testToken);
        assert(heroToken.ownerOf(testToken) == testUser);

        // confirm claimableRewards increase for testUser
        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeMintClaimable + 
            testHeroFee - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );
    }

    function testRageQuitThenHeroMintSameToken() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken2);
        burner.depositSpirit(testToken2);

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);
        assert(genesisToken.ownerOf(testToken) == address(burner));

        weth.approve(address(burner), testHeroFee * 2);

        assert(spiritToken.ownerOf(testToken2) == address(burner));
        burner.enterHeroQuest(testToken2, testToken);

        uint256 beforeQuitClaimable = burner.getGenesisData(testToken).claimableRewards;
        burner.rageQuitHeroQuest(testToken2);
        assert(spiritToken.ownerOf(testToken2) == testUser);

        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeQuitClaimable + 
            (testHeroFee / 2) - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );

        spiritToken.approve(address(burner), testToken2);
        burner.depositSpirit(testToken2);
        assert(spiritToken.ownerOf(testToken2) == address(burner));

        burner.enterHeroQuest(testToken2, testToken);
        vm.warp(block.timestamp + 1 days);

        uint256 beforeMintClaimable = burner.getGenesisData(testToken).claimableRewards;

        burner.mintHero(testToken2);
        assert(heroToken.ownerOf(testToken2) == testUser);

        // confirm claimableRewards increase for testUser
        assert(
            burner.getGenesisData(testToken).claimableRewards == beforeMintClaimable + 
            testHeroFee - testHeroFee.mul(burner.CONTRACT_FEE_BPS()).div(burner.MAX_BPS())
        );
    }
    
}
