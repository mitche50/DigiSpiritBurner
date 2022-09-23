// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import './Adventure/DigiDaigaku.sol';
import './Adventure/DigiDaigakuHeroes.sol';
import './Adventure/DigiDaigakuSpirits.sol';
import './Adventure/HeroAdventure.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DigiSpiritBurner is AdventurePermissions {

    DigiDaigaku genesisToken = DigiDaigaku(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9);
    DigiDaigakuHeroes heroToken = DigiDaigakuHeroes(0xA225632b2EBc32B9f4278fc8E3FE5C6f6496D970);
    DigiDaigakuSpirits spiritToken = DigiDaigakuSpirits(0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973);
    HeroAdventure adventure = HeroAdventure(0xE60fE8C4C60Fd97f939F5136cCeb7c41EaaA624d);
    ERC20 weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    mapping(uint16 => uint256) public heroFee;

    mapping(uint16 => bool) public genesisIsDeposited;
    mapping(uint16 => address) private _genesisOwner;

    mapping(uint16 => address) private _spiritOwner;
    mapping(uint16 => uint16) private _spiritGenesisAdventurePair;

    event GenesisDeposited(uint16 tokenId, address owner, uint256 fee);
    event GenesisWithdrawn(uint16 tokenId, address owner);
    event GenesisFeeUpdated(uint16 tokenId, uint256 oldFee, uint256 newFee);
    event SpiritDeposited(uint16 tokenId, address owner);
    event HeroMinted(uint16 spiritId, address owner);


    constructor() {
    }

    modifier onlyGenesisOwner(uint16 tokenId) {
        require(_msgSender() == _genesisOwner[tokenId], "Not original owner of genesis");
        _;
    }

    modifier onlySpiritOwner(uint16 tokenId) {
        require(_msgSender() == _spiritOwner[tokenId], "Not original owner of spirit");
        _;
    }

    /**
     * @notice Deposits genesis token into contract for "purposes"
     * @param tokenId ID of genesis token to deposit
     * @param fee Fee to charge users for breeding with your genesis NFT
     */
    function depositGenesis(uint16 tokenId, uint256 fee) external {
        genesisToken.transferFrom(_msgSender(), address(this), tokenId);
        _genesisOwner[tokenId] = _msgSender();
        heroFee[tokenId] = fee;
        genesisIsDeposited[tokenId] = true;

        emit GenesisDeposited(tokenId, _msgSender(), fee);
    }

    /**
     * @notice Withdraw Genesis token
     * @param tokenId ID of the genesis token to be withdrawn
     */
    function withdrawGenesis(uint16 tokenId) external onlyGenesisOwner(tokenId) {
        genesisToken.transferFrom(address(this), _msgSender(), tokenId);
        _genesisOwner[tokenId] = address(0);
        heroFee[tokenId] = 0;
        genesisIsDeposited[tokenId] = false;

        emit GenesisWithdrawn(tokenId, _msgSender());
    }

    /**
     * @notice Update the fee associated with your Genesis token
     * @param tokenId ID of the genesis token to update fee for
     * @param newFee New fee to set
     */
     function updateGenesisFee(uint16 tokenId, uint256 newFee) external onlyGenesisOwner(tokenId) {
        uint256 oldFee = heroFee[tokenId];
        heroFee[tokenId] = newFee;

        emit GenesisFeeUpdated(tokenId, oldFee, newFee);
     }

    /**
     * @notice Deposits spirit token into contract
     * @param tokenId ID of spirit to be deposited into the contract
     */
    function depositSpirit(uint16 tokenId) external {
        require(spiritToken.areAdventuresApprovedForAll(_msgSender(), address(this)), "Must approve contract for adventure first");
        spiritToken.transferFrom(_msgSender(), address(this), tokenId);
        _spiritOwner[tokenId] = _msgSender();

        emit SpiritDeposited(tokenId, _msgSender());
    }

    /**
     * @notice Withdraw an unspent spirit
     * @param tokenId ID of the token to be burnt for a hero
     */
    function withdrawSpirit(uint16 tokenId) external onlySpiritOwner(tokenId) {
        spiritToken.transferFrom(address(this), _msgSender(), tokenId);
    }

    /**
     * @notice Enter the hero quest with the provided spirit and genesis token pair
     * @param spiritId ID of the spirit token to be burnt for a hero
     * @param genesisId ID of the genesis token to be used
     */
    function enterHeroQuest(uint16 spiritId, uint16 genesisId) external onlySpiritOwner(spiritId) {
        adventure.enterQuest(spiritId, genesisId);
        _spiritGenesisAdventurePair[spiritId] = genesisId;
    }

    /**
     * @notice Remove spirit from quest and return to user without minting hero
     * @notice allows for a user to remove their spirit before the duration of the quest is completed
     * @notice but costs half of the heroFee assigned to the genesis token to prevent griefing
     * @dev Requires the user to have approved the contract to spend wETH fee
     * @param spiritId ID of the spirit token to be burnt for a hero
     */
    function rageQuitHeroQuest(uint16 spiritId) external onlySpiritOwner(spiritId) {
        // Transfer wETH Fee to Genesis Holder (halved due to not getting hero)
        uint16 genesisId = _spiritGenesisAdventurePair[spiritId];
        weth.transferFrom(_msgSender(), _genesisOwner[genesisId], heroFee[genesisId] / 2);
        adventure.exitQuest(spiritId, false);
        spiritToken.transferFrom(address(this), _msgSender(), spiritId);
    }

    /**
     * @notice Mint a hero from the provided token ID.
     * @dev Requires the user to have waited the `HERO_QUEST_DURATION` from the HeroAdventure contract
     * @dev and the user to have approved the contract to spend wETH fee
     * @param spiritId ID of the spirit token to be burnt for a hero
     */
    function mintHero(uint16 spiritId) external onlySpiritOwner(spiritId) {
        // Transfer wETH Fee to Genesis Holder
        uint16 genesisId = _spiritGenesisAdventurePair[spiritId];
        weth.transferFrom(_msgSender(), _genesisOwner[genesisId], heroFee[genesisId]);

        adventure.exitQuest(spiritId, true);
        heroToken.transferFrom(address(this), _msgSender(), spiritId);
    }
}
