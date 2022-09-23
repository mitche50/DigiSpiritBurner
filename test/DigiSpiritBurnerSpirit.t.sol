// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "src/DigiSpiritBurner.sol";
import "src/Adventure/DigiDaigaku.sol";
import 'src/Adventure/DigiDaigakuHeroes.sol';
import "src/Adventure/DigiDaigakuSpirits.sol";
import 'src/Adventure/HeroAdventure.sol';
import "src/Token/IWETH.sol";

contract DigiSpiritBurnerTest is Test {

    address testUser = 0x76b2F9CAA443812D88693b86AdD2800F5F535C51;
    address badUser = 0x822a02E58919233821f4a5Bd5EfF4a214cCAB7AC;
    uint16 testToken = 467;

    DigiSpiritBurner burner;
    HeroAdventure adventure = HeroAdventure(0xE60fE8C4C60Fd97f939F5136cCeb7c41EaaA624d);
    DigiDaigaku genesisToken = DigiDaigaku(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9);
    DigiDaigakuHeroes heroToken = DigiDaigakuHeroes(0xA225632b2EBc32B9f4278fc8E3FE5C6f6496D970);
    DigiDaigakuSpirits spiritToken = DigiDaigakuSpirits(0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973);

    IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        burner = new DigiSpiritBurner();
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

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);
        assert(spiritToken.ownerOf(testToken) == address(burner));

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);
        assert(genesisToken.ownerOf(testToken) == address(burner));

        burner.enterHeroQuest(testToken, testToken);
        vm.stopPrank();
    }

    function testRageQuit() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        burner.depositSpirit(testToken);
        
        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);

        burner.enterHeroQuest(testToken, testToken);

        // wrap ETH
        weth.deposit{value:5e17}();
        weth.approve(address(burner), 5e17);

        burner.rageQuitHeroQuest(testToken);

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

        burner.enterHeroQuest(testToken, testToken);
        vm.warp(block.timestamp + 1 days);

        // wrap ETH
        weth.deposit{value:1e18}();
        weth.approve(address(burner), 1e18);

        burner.mintHero(testToken);
        assert(heroToken.ownerOf(testToken) == testUser);

        vm.stopPrank();
    }

    // TODO: Finish mint hero function and write tests
    // function testMintHero() public {
    //     vm.startPrank(testUser);

    //     // deposit genesis
    //     genesisToken.approve(address(burner), testToken);
    //     burner.depositGenesis(testToken, 1e18);
        
    //     // deposit spirit
    //     spiritToken.approve(address(burner), testToken);
    //     burner.depositSpirit(testToken);

    //     // //wrap ETH
    //     weth.deposit{value:1e18}();
    //     weth.approve(address(burner), 1e18);

    //     burner.mintHero(testToken, testToken);

    // }
    
}
