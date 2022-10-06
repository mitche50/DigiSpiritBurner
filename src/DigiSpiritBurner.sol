// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Adventure/DigiDaigaku.sol";
import "./Adventure/DigiDaigakuHeroes.sol";
import "./Adventure/DigiDaigakuSpirits.sol";
import "./Adventure/HeroAdventure.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DigiSpiritBurner is Context {
    using SafeMath for uint256;

    DigiDaigaku genesisToken =
        DigiDaigaku(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9);
    DigiDaigakuHeroes heroToken =
        DigiDaigakuHeroes(0xA225632b2EBc32B9f4278fc8E3FE5C6f6496D970);
    DigiDaigakuSpirits spiritToken =
        DigiDaigakuSpirits(0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973);
    HeroAdventure adventure =
        HeroAdventure(0xE60fE8C4C60Fd97f939F5136cCeb7c41EaaA624d);
    ERC20 weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    mapping(uint16 => uint256) public heroFee;

    mapping(uint16 => bool) public genesisIsDeposited;
    mapping(uint16 => address) private _genesisOwner;

    mapping(uint16 => address) private _spiritOwner;
    mapping(uint16 => uint16) private _spiritGenesisAdventurePair;

    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public claimableRewards;
    uint256 private _contractClaimableRewards;
    address contractClaimer;

    uint256 public constant MAX_BPS = 10_000;
    uint256 public constant CONTRACT_FEE_BPS = 250;

    event GenesisDeposited(uint16 tokenId, address owner, uint256 fee);
    event GenesisWithdrawn(uint16 tokenId, address owner);
    event GenesisFeeUpdated(uint16 tokenId, uint256 oldFee, uint256 newFee);
    event SpiritDeposited(uint16 tokenId, address owner);
    event HeroMinted(uint16 spiritId, address owner);
    event RewardClaimed(address claimer, uint256 amount);

    constructor () {
        spiritToken.setAdventuresApprovedForAll(address(adventure), true);
        contractClaimer = _msgSender();
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
        claimableRewards[_msgSender()] = 0;
        pendingRewards[_msgSender()] = 0;

        emit GenesisDeposited(tokenId, _msgSender(), fee);
    }

    /**
     * @notice Withdraw Genesis token
     * @param tokenId ID of the genesis token to be withdrawn
     */
    function withdrawGenesis(uint16 tokenId)
        external
        onlyGenesisOwner(tokenId)
    {
        require(genesisToken.ownerOf(tokenId) == address(this), 'Genesis not in contract');
        genesisToken.transferFrom(address(this), _msgSender(), tokenId);

        uint256 toClaim = claimableRewards[_msgSender()];
        claimableRewards[_msgSender()] = 0;
        if(toClaim > 0) {
            weth.transferFrom(address(this), _msgSender(), toClaim);
        }

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
    function updateGenesisFee(uint16 tokenId, uint256 newFee)
        external
        onlyGenesisOwner(tokenId)
    {
        require(genesisToken.ownerOf(tokenId) == address(this), "Genesis must be home to update fee");
        uint256 oldFee = heroFee[tokenId];
        heroFee[tokenId] = newFee;

        emit GenesisFeeUpdated(tokenId, oldFee, newFee);
    }

    /**
     * @notice Deposits spirit token into contract
     * @param tokenId ID of spirit to be deposited into the contract
     */
    function depositSpirit(uint16 tokenId) external {
        spiritToken.transferFrom(_msgSender(), address(this), tokenId);
        _spiritOwner[tokenId] = _msgSender();

        emit SpiritDeposited(tokenId, _msgSender());
    }

    /**
     * @notice Withdraw an unspent spirit
     * @param tokenId ID of the token to be burnt for a hero
     */
    function withdrawSpirit(uint16 tokenId)
        external
        onlySpiritOwner(tokenId)
    {
        require(_spiritGenesisAdventurePair[tokenId] == 0, 'Mint or quit quest to withdraw');
        spiritToken.transferFrom(address(this), _msgSender(), tokenId);
    }

    /**
     * @notice Enter the hero quest with the provided spirit and genesis token pair
     * @notice Payment is required up front for the hero token, with half being refunded
     * @notice if you decide to cancel before the quest is finished.
     * @param spiritId ID of the spirit token to be burnt for a hero
     * @param genesisId ID of the genesis token to be used
     */
    function enterHeroQuest(uint16 spiritId, uint16 genesisId)
        external
        onlySpiritOwner(spiritId)
    {
        // Transfer wETH to the contract
        weth.transferFrom(_msgSender(), address(this), heroFee[genesisId]);
        
        // Assign pending rewards to genesis 
        pendingRewards[_genesisOwner[genesisId]] += heroFee[genesisId];

        genesisToken.approve(address(adventure), genesisId);
        adventure.enterQuest(spiritId, genesisId);
        _spiritGenesisAdventurePair[spiritId] = genesisId;
    }

    /**
     * @notice Remove spirit from quest and return to user without minting hero
     * @notice allows for a user to remove their spirit before the duration of the quest is completed
     * @notice but costs half of the heroFee assigned to the genesis token to prevent griefing
     * @param spiritId ID of the spirit token to be burnt for a hero
     */
    function rageQuitHeroQuest(uint16 spiritId)
        external
        onlySpiritOwner(spiritId)
    {
        // Assign claimable rewards to Genesis Holder (halved due to not getting hero)
        uint16 genesisId = _spiritGenesisAdventurePair[spiritId];
        require(genesisId > 0, 'Spirit is not on a hero quest');

        address genesisHolder = _genesisOwner[genesisId];
        uint256 fee = heroFee[genesisId] / 2;
        uint256 contractFee = _calculateFee(fee, CONTRACT_FEE_BPS);

        pendingRewards[genesisHolder] -= fee;
        claimableRewards[genesisHolder] += fee - contractFee;
        _contractClaimableRewards += contractFee;

        adventure.exitQuest(spiritId, false);
        delete _spiritGenesisAdventurePair[spiritId];

        // Return spirit token and remaining wETH to owner
        spiritToken.transferFrom(address(this), _msgSender(), spiritId);
        weth.transferFrom(address(this), _msgSender(), heroFee[genesisId] - fee);
    }

    /**
     * @notice Mint a hero from the provided token ID.
     * @notice Anyone can perform this action as the fee has already been collected from the spirit owner
     * @dev Requires the user to have waited the `HERO_QUEST_DURATION` from the HeroAdventure contract
     * @param spiritId ID of the spirit token to be burnt for a hero
     */
    function mintHero(uint16 spiritId) external {
        // Transfer wETH Fee to Genesis Holder
        uint16 genesisId = _spiritGenesisAdventurePair[spiritId];
        require(genesisId > 0, 'Spirit is not on a hero quest');
        address genesisHolder = _genesisOwner[genesisId];

        uint256 fee = heroFee[genesisId];
        uint256 contractFee = _calculateFee(fee, CONTRACT_FEE_BPS);
        
        pendingRewards[genesisHolder] -= fee;
        claimableRewards[genesisHolder] += fee - contractFee;
        _contractClaimableRewards += contractFee;

        adventure.exitQuest(spiritId, true);
        heroToken.transferFrom(address(this), _spiritOwner[spiritId], spiritId);
        delete _spiritGenesisAdventurePair[spiritId];

        emit HeroMinted(spiritId, _spiritOwner[spiritId]);
    }

    /**
     * @notice Claim the rewards allocated to the caller's address
     */
    function claimRewards() external {
        require(claimableRewards[_msgSender()] > 0, 'No claimable rewards');
        uint256 toClaim = claimableRewards[_msgSender()];
        delete claimableRewards[_msgSender()];
        weth.transferFrom(address(this), _msgSender(), toClaim);

        emit RewardClaimed(_msgSender(), toClaim);
    }

    /**
     * @notice Claim the rewards allocated to the contract
     */
     function claimContractRewards() external {
        require(_msgSender() == contractClaimer, 'Only contract claimer');
        uint256 toClaim = _contractClaimableRewards;
        _contractClaimableRewards = 0;
        weth.transferFrom(address(this), contractClaimer, toClaim);

        emit RewardClaimed(_msgSender(), toClaim);
     }

     /**
     * @notice Update the contract claimer
     */
     function updateContractClaimer(address newClaimer) external {
        require(_msgSender() == contractClaimer, 'Only contract claimer');
        contractClaimer = newClaimer;
     }

    /**
     * @dev Helper function to calculate fees.
     * @param amount Amount to calculate fee on.
     * @param feeBps The fee to be charged in basis points.
     * @return Amount of fees to take.
     */
    function _calculateFee(uint256 amount, uint256 feeBps) internal pure returns (uint256) {
        if (feeBps == 0) {
            return 0;
        }
        uint256 fee = amount.mul(feeBps).div(MAX_BPS);
        return fee;
    }

}