// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "forge-std/console.sol";
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

        vm.startPrank(testUser);

        assert(burner.getGenesisData(testToken).owner == address(0));

        genesisToken.approve(address(burner), testToken);
        burner.depositGenesis(testToken, 1e18);

        assert(burner.getGenesisData(testToken).owner == testUser);
        assert(genesisToken.ownerOf(testToken) == address(burner));
        assert(burner.getGenesisData(testToken).heroFee == 1e18);

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
    
}
