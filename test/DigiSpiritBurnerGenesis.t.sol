// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/DigiSpiritBurner.sol";
import "src/Adventure/DigiDaigaku.sol";
import "src/Adventure/DigiDaigakuSpirits.sol";
import "src/Token/IWETH.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DigiSpiritBurnerTest is Test {
    using SafeMath for uint256;

    address testUser = 0x76b2F9CAA443812D88693b86AdD2800F5F535C51;
    address badUser = 0x822a02E58919233821f4a5Bd5EfF4a214cCAB7AC;
    address secondaryUser = 0xB573DB1b2Dc80dCB995a333aBAe20DF9fF6C751A;
    uint16 testToken = 467;
    uint256 testHeroFee = 1e18;

    DigiSpiritBurner burner;
    DigiDaigaku genesisToken = DigiDaigaku(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9);
    DigiDaigakuSpirits spiritToken = DigiDaigakuSpirits(0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973);

    address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWETH weth = IWETH(wethAddress);

    function setUp() public {
        burner = new DigiSpiritBurner(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9, 0xA225632b2EBc32B9f4278fc8E3FE5C6f6496D970, 0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973, 0xE60fE8C4C60Fd97f939F5136cCeb7c41EaaA624d, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        deal(wethAddress, testUser, 10e18);
        deal(wethAddress, badUser, 10e18);
        deal(wethAddress, secondaryUser, 10e18);

        vm.startPrank(testUser);

        assert(burner.getGenesisData(testToken).owner == address(0));

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);

        assert(burner.getGenesisData(testToken).owner == testUser);
        assert(genesisToken.ownerOf(testToken) == address(burner));
        assert(burner.getGenesisData(testToken).heroFee == 1e18);
        assert(burner.getGenesisDepositedArray()[0] == testToken);

        vm.stopPrank();
    }

    function testGenesisWithdrawal() public {
        vm.startPrank(testUser);

        assert(burner.getGenesisData(testToken).owner != address(0));
        assert(genesisToken.ownerOf(testToken) == address(burner));

        burner.withdrawGenesis(testToken);

        assert(burner.getGenesisData(testToken).owner == address(0));
        assert(genesisToken.ownerOf(testToken) == testUser);

        vm.stopPrank();
    }

    function testGenesisWithdrawNotOwner() public {
        vm.startPrank(badUser);

        vm.expectRevert(bytes("Not original owner of genesis"));
        burner.withdrawGenesis(testToken);

        vm.stopPrank();
    }

    function testGenesisFeeChange() public {
        vm.startPrank(testUser);

        assert(burner.getGenesisData(testToken).heroFee == 1e18);

        burner.updateGenesisFee(testToken, 2e18);

        assert(burner.getGenesisData(testToken).heroFee == 2e18);

        vm.stopPrank();
    }

    function testGenesisFeeChangeNotOwner() public {
        vm.startPrank(badUser);

        vm.expectRevert(bytes("Not original owner of genesis"));
        burner.updateGenesisFee(testToken, 2e18);

        vm.stopPrank();

        assert(burner.getGenesisData(testToken).heroFee == 1e18);
    }

    function testGenesisRewardClaim() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);

        weth.approve(address(burner), testHeroFee);

        burner.enterHeroQuest(testToken, testToken);
        vm.warp(block.timestamp + 1 days);

        uint256 beforeClaimBalance = weth.balanceOf(testUser);

        burner.mintHero(testToken);

        uint256 claimableBalance = burner.getGenesisData(testToken).claimableRewards;

        burner.claimRewards(testToken);

        assert(weth.balanceOf(testUser) == beforeClaimBalance + claimableBalance);
        assert(burner.getGenesisData(testToken).claimableRewards == 0);

        vm.stopPrank();
    }

    // Confirms that a genesis owner can trigger the mint of a hero if a secondary
    // user is holding it hostage and still receive their fees
    function testGenesisOwnerMintHero() public {
        vm.prank(testUser);
        spiritToken.transferFrom(testUser, secondaryUser, testToken);

        vm.startPrank(secondaryUser);
        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);

        weth.approve(address(burner), testHeroFee);

        burner.enterHeroQuest(testToken, testToken);
        vm.warp(block.timestamp + 1 days);

        vm.stopPrank();

        vm.startPrank(testUser);

        uint256 beforeClaimBalance = weth.balanceOf(testUser);

        burner.mintHero(testToken);

        uint256 claimableBalance = burner.getGenesisData(testToken).claimableRewards;

        burner.claimRewards(testToken);

        assert(weth.balanceOf(testUser) == beforeClaimBalance + claimableBalance);
        assert(burner.getGenesisData(testToken).claimableRewards == 0);

        vm.stopPrank();
    }
    
}
