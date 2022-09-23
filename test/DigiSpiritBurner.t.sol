// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "src/DigiSpiritBurner.sol";
import "src/Adventure/DigiDaigaku.sol";
import "src/Adventure/DigiDaigakuSpirits.sol";
import "src/Token/IWETH.sol";

contract DigiSpiritBurnerTest is Test {

    address testUser = 0x76b2F9CAA443812D88693b86AdD2800F5F535C51;
    address badUser = 0x822a02E58919233821f4a5Bd5EfF4a214cCAB7AC;
    uint16 testToken = 467;

    DigiSpiritBurner burner;
    DigiDaigaku genesisToken = DigiDaigaku(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9);
    DigiDaigakuSpirits spiritToken = DigiDaigakuSpirits(0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973);

    IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        burner = new DigiSpiritBurner();
    }

    function testGenesisDeposit() public {
        vm.startPrank(testUser);

        assert(!burner.genesisDeposited(testToken));

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);

        assert(burner.genesisDeposited(testToken));
        assert(genesisToken.ownerOf(testToken) == address(burner));
        assert(burner.heroFee(testToken) == 1e18);

        vm.stopPrank();
    }

    function testGenesisWithdrawal() public {
        vm.startPrank(testUser);

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);

        assert(burner.genesisDeposited(testToken));

        burner.withdrawGenesis(testToken);

        assert(!burner.genesisDeposited(testToken));
        assert(genesisToken.ownerOf(testToken) == testUser);

        vm.stopPrank();
    }

    function testGenesisWithdrawNotOwner() public {
        vm.startPrank(testUser);

        assert(!burner.genesisDeposited(testToken));

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);

        assert(burner.genesisDeposited(testToken));

        vm.stopPrank();

        vm.startPrank(badUser);

        vm.expectRevert(bytes("Not original owner of genesis"));
        burner.withdrawGenesis(testToken);

        vm.stopPrank();
    }

    function testSpiritDeposit() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        spiritToken.setAdventuresApprovedForAll(address(burner), true);
        burner.depositSpirit(testToken);

        assert(spiritToken.ownerOf(testToken) == address(burner));

        vm.stopPrank();
    }

    function testSpiritDepositNotApprovedForAdventure() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        vm.expectRevert(bytes("Must approve contract for adventure first"));
        burner.depositSpirit(testToken);

        vm.stopPrank();
    }

    function testSpiritWithdrawal() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        spiritToken.setAdventuresApprovedForAll(address(burner), true);
        burner.depositSpirit(testToken);

        assert(spiritToken.ownerOf(testToken) == address(burner));

        burner.withdrawSpirit(testToken);

        assert(spiritToken.ownerOf(testToken) == testUser);

        vm.stopPrank();
    }

    function testSpiritWithdrawalNotOwner() public {
        vm.startPrank(testUser);

        spiritToken.approve(address(burner), testToken);
        spiritToken.setAdventuresApprovedForAll(address(burner), true);
        burner.depositSpirit(testToken);

        assert(spiritToken.ownerOf(testToken) == address(burner));

        vm.stopPrank();

        vm.startPrank(badUser);

        vm.expectRevert(bytes("Not original owner of spirit"));
        burner.withdrawSpirit(testToken);

        vm.stopPrank();
    }

    function testGenesisFeeChange() public {
        vm.startPrank(testUser);

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);

        assert(burner.heroFee(testToken) == 1e18);

        burner.updateGenesisFee(testToken, 2e18);

        assert(burner.heroFee(testToken) == 2e18);
    }

    function testGenesisFeeChangeNotOwner() public {
        vm.startPrank(testUser);

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);

        vm.stopPrank();

        vm.startPrank(badUser);

        vm.expectRevert(bytes("Not original owner of genesis"));
        burner.updateGenesisFee(testToken, 2e18);

        vm.stopPrank();

        assert(burner.heroFee(testToken) == 1e18);
    }

    // TODO: Finish mint hero function and write tests
    // function testMintHero() public {
    //     vm.startPrank(testUser);

    //     // deposit genesis
    //     genesisToken.approve(address(burner), testToken);
    //     burner.depositGenesis(testToken, 1e18);
        
    //     // deposit spirit
    //     spiritToken.approve(address(burner), testToken);
    //     spiritToken.setAdventuresApprovedForAll(address(burner), true);
    //     burner.depositSpirit(testToken);

    //     // //wrap ETH
    //     weth.deposit{value:1e18}();
    //     weth.approve(address(burner), 1e18);

    //     burner.mintHero(testToken, testToken);

    // }
    
}
