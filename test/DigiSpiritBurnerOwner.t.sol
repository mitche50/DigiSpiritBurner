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
    uint16 testToken = 467;
    uint256 testHeroFee = 1e18;
    address owner;

    DigiSpiritBurner burner;
    DigiDaigaku genesisToken = DigiDaigaku(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9);
    DigiDaigakuSpirits spiritToken = DigiDaigakuSpirits(0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973);

    address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWETH weth = IWETH(wethAddress);

    function setUp() public {
        burner = new DigiSpiritBurner(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9, 0xA225632b2EBc32B9f4278fc8E3FE5C6f6496D970, 0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973, 0xE60fE8C4C60Fd97f939F5136cCeb7c41EaaA624d, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        owner = burner.contractClaimer();

        deal(wethAddress, testUser, 10e18);

        vm.startPrank(testUser);

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);
        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);

        weth.approve(address(burner), testHeroFee);

        burner.enterHeroQuest(testToken, testToken);

        vm.stopPrank();
    }

    function testMintHeroClaim() public {
        uint256 beforeMintBalance = weth.balanceOf(owner);

        vm.warp(block.timestamp + 1 days);
        vm.prank(testUser);
        burner.mintHero(testToken);
        uint256 claimableBalance = burner.contractClaimableRewards();

        vm.prank(owner);
        burner.claimContractRewards();

        assert(weth.balanceOf(owner) == beforeMintBalance + claimableBalance);
        assert(burner.contractClaimableRewards() == 0);

        vm.stopPrank();
    }

    function testRageQuitClaim() public {
        uint256 beforeMintBalance = weth.balanceOf(owner);

        vm.prank(testUser);
        burner.rageQuitHeroQuest(testToken);
        uint256 claimableBalance = burner.contractClaimableRewards();

        vm.prank(owner);
        burner.claimContractRewards();

        assert(weth.balanceOf(owner) == beforeMintBalance + claimableBalance);
        assert(burner.contractClaimableRewards() == 0);

        vm.stopPrank();
    }
}