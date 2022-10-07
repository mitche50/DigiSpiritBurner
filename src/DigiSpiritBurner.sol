// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Adventure/DigiDaigaku.sol";
import "./Adventure/DigiDaigakuHeroes.sol";
import "./Adventure/DigiDaigakuSpirits.sol";
import "./Adventure/HeroAdventure.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DigiSpiritBurner is Context {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    DigiDaigaku public genesisToken;
    DigiDaigakuHeroes public heroToken;
    DigiDaigakuSpirits public spiritToken;
    HeroAdventure public adventure;
    IERC20 public weth;

    struct GenesisData {
        address owner;
        uint256 heroFee;
        uint256 pendingRewards;
        uint256 claimableRewards;
        uint16 adventuringSpirit;
    }

    struct SpiritData {
        address owner;
        uint16 adventureGenesis;
    }

    mapping(uint16 => GenesisData) private _genesisData;
    mapping(uint16 => SpiritData) private _spiritData;

    uint16[] private _depositedGenesisTokens;

    uint256 public contractClaimableRewards;
    address public contractClaimer;

    uint256 public constant MAX_BPS = 10_000;
    uint256 public constant CONTRACT_FEE_BPS = 250;

    event GenesisDeposited(uint16 tokenId, address owner, uint256 fee);
    event GenesisWithdrawn(uint16 tokenId, address owner);
    event GenesisFeeUpdated(uint16 tokenId, uint256 oldFee, uint256 newFee);
    event SpiritDeposited(uint16 tokenId, address owner);
    event HeroMinted(uint16 spiritId, address owner);
    event RewardClaimed(address claimer, uint256 amount);

    constructor (address _genesisToken, address _heroToken, address _spiritToken, address _adventure, address _weth) {
        contractClaimer = _msgSender();
        genesisToken = DigiDaigaku(_genesisToken);
        heroToken = DigiDaigakuHeroes(_heroToken);
        spiritToken = DigiDaigakuSpirits(_spiritToken);
        adventure = HeroAdventure(_adventure);
        weth = IERC20(_weth);

        spiritToken.setAdventuresApprovedForAll(address(adventure), true);
        genesisToken.setApprovalForAll(address(adventure), true);
    }

    modifier onlyGenesisOwner(uint16 tokenId) {
        require(_msgSender() == _genesisData[tokenId].owner, "Not original owner of genesis");
        _;
    }

    modifier onlySpiritOwner(uint16 tokenId) {
        require(_msgSender() == _spiritData[tokenId].owner, "Not original owner of spirit");
        _;
    }

    // ***************** VIEW FUNCTIONS *****************

    /**
     * @notice View function to return Genesis Data struct for provided token ID
     * @param tokenId Genesis ID to return data for
     * @return GenesisData Struct containing data for the provided genesis token ID
     */
    function getGenesisData(uint16 tokenId) external view returns (GenesisData memory) {
        return _genesisData[tokenId];
    }

    /**
     * @notice View function to return the full list of deposited genesis tokens
     * @return uint16[] Array containing all deposited genesis tokens
     */
    function getGenesisDepositedArray() external view returns (uint16[] memory) {
        return _depositedGenesisTokens;
    }

    // ***************** PUBLIC FUNCTIONS  *****************

    /**
     * @notice Deposits spirit token into contract
     * @param tokenId ID of spirit to be deposited into the contract
     */
    function depositSpirit(uint16 tokenId) external {
        spiritToken.transferFrom(_msgSender(), address(this), tokenId);
        _spiritData[tokenId] = SpiritData({
            owner: _msgSender(),
            adventureGenesis: 0
        });

        emit SpiritDeposited(tokenId, _msgSender());
    }

    /**
     * @notice Deposits genesis token into contract for "purposes"
     * @param tokenId ID of genesis token to deposit
     * @param fee Fee to charge users for breeding with your genesis NFT (in BPS)
     */
    function depositGenesis(uint16 tokenId, uint256 fee) external {
        genesisToken.transferFrom(_msgSender(), address(this), tokenId);
        _genesisData[tokenId] = GenesisData({
            heroFee: fee,
            owner: _msgSender(),
            pendingRewards: 0,
            claimableRewards: 0,
            adventuringSpirit: 0
        });
        _depositedGenesisTokens.push(tokenId);

        emit GenesisDeposited(tokenId, _msgSender(), fee);
    }

    /**
     * @notice Mint a hero from the provided token ID.
     * @notice Anyone can perform this action as the fee has already been collected from the spirit owner
     * @dev Requires the user to have waited the `HERO_QUEST_DURATION` from the HeroAdventure contract
     * @param spiritId ID of the spirit token to be burnt for a hero
     */
    function mintHero(uint16 spiritId) external {
        uint16 genesisId = _spiritData[spiritId].adventureGenesis;
        require(genesisId > 0, 'Spirit is not on a hero quest');

        uint256 fee = _genesisData[genesisId].heroFee;
        uint256 contractFee = _calculateFee(fee, CONTRACT_FEE_BPS);
        
        _genesisData[genesisId].pendingRewards -= fee;
        _genesisData[genesisId].claimableRewards += fee - contractFee;
        contractClaimableRewards += contractFee;

        address spiritOwner = _spiritData[spiritId].owner;

        delete _spiritData[spiritId];
        _genesisData[genesisId].adventuringSpirit = 0;

        adventure.exitQuest(spiritId, true);
        heroToken.transferFrom(address(this), spiritOwner, spiritId);

        emit HeroMinted(spiritId, spiritOwner);
    }

    /**
     * @notice Claim the rewards allocated to the genesis token's owner
     * @param genesisId ID of genesis token's rewards to claim
     */
    function claimRewards(uint16 genesisId) external {
        require(_genesisData[genesisId].claimableRewards > 0, 'No claimable rewards');
        uint256 toClaim = _genesisData[genesisId].claimableRewards;
        _genesisData[genesisId].claimableRewards = 0;
        weth.safeTransferFrom(address(this), _genesisData[genesisId].owner, toClaim);

        emit RewardClaimed(_genesisData[genesisId].owner, toClaim);
    }

    // ***************** GENESIS FUNCTIONS  *****************

    /**
     * @notice Withdraw Genesis token
     * @param tokenId ID of the genesis token to be withdrawn
     */
    function withdrawGenesis(uint16 tokenId)
        external
        onlyGenesisOwner(tokenId)
    {
        require(genesisToken.ownerOf(tokenId) == address(this), 'Genesis not in contract');

        uint256 toClaim = _genesisData[tokenId].claimableRewards;
        delete _genesisData[tokenId];
        _removeToken(tokenId, _depositedGenesisTokens);

        if(toClaim > 0) {
            weth.safeTransferFrom(address(this), _msgSender(), toClaim);
        }

        genesisToken.transferFrom(address(this), _msgSender(), tokenId);

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
        uint256 oldFee = _genesisData[tokenId].heroFee;
        _genesisData[tokenId].heroFee = newFee;

        emit GenesisFeeUpdated(tokenId, oldFee, newFee);
    }

    // ***************** SPIRIT FUNCTIONS  *****************

    /**
     * @notice Withdraw an unspent spirit
     * @param tokenId ID of the token to be burnt for a hero
     */
    function withdrawSpirit(uint16 tokenId)
        external
        onlySpiritOwner(tokenId)
    {
        require(_spiritData[tokenId].adventureGenesis == 0, 'Mint or quit quest to withdraw');
        delete _spiritData[tokenId];

        spiritToken.transferFrom(address(this), _msgSender(), tokenId);
    }

    /**
     * @notice Enter the hero quest with the provided spirit and genesis token pair
     * @notice Payment is required up front for the hero token, with half being refunded
     * @notice if you decide to cancel before the quest is finished.
     * @param spiritId ID of the spirit token to be burnt for a hero
     * @param genesisId ID of the genesis token to be used
     * @param maxHeroFee maximum amount of wETH to send to contract
     */
    function enterHeroQuest(uint16 spiritId, uint16 genesisId, uint256 maxHeroFee)
        external
        onlySpiritOwner(spiritId)
    {
        // Assign pending rewards to genesis 
        _genesisData[genesisId].pendingRewards += _genesisData[genesisId].heroFee;    
        _spiritData[spiritId].adventureGenesis = genesisId;
        _genesisData[genesisId].adventuringSpirit = spiritId;

        // Transfer wETH to the contract
        require(maxHeroFee >= _genesisData[genesisId].heroFee, 'Hero fee > max you want to pay');
        require(weth.allowance(_msgSender(), address(this)) >= _genesisData[genesisId].heroFee, 'WETH not approved');
        weth.safeTransferFrom(_msgSender(), address(this), _genesisData[genesisId].heroFee);

        adventure.enterQuest(spiritId, genesisId);
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
        uint16 genesisId = _spiritData[spiritId].adventureGenesis;
        require(genesisId > 0, 'Spirit is not on a hero quest');

        uint256 halvedFee = _genesisData[genesisId].heroFee / 2;
        uint256 contractFee = _calculateFee(_genesisData[genesisId].heroFee, CONTRACT_FEE_BPS);

        _genesisData[genesisId].pendingRewards -= _genesisData[genesisId].heroFee;
        _genesisData[genesisId].claimableRewards += halvedFee - contractFee;
        contractClaimableRewards += contractFee;

        delete _spiritData[spiritId];
        _genesisData[genesisId].adventuringSpirit = 0;

        // Return spirit token and remaining wETH to owner
        adventure.exitQuest(spiritId, false);
        spiritToken.transferFrom(address(this), _msgSender(), spiritId);
        weth.safeTransferFrom(address(this), _msgSender(), _genesisData[genesisId].heroFee - halvedFee);
    }

    /**
     * @notice Claim the rewards allocated to the contract
     */
     function claimContractRewards() external {
        require(_msgSender() == contractClaimer, 'Not contract claimer');
        require(contractClaimableRewards > 0, 'No claimable rewards');
        uint256 toClaim = contractClaimableRewards;
        contractClaimableRewards = 0;
        weth.safeTransferFrom(address(this), contractClaimer, toClaim);

        emit RewardClaimed(_msgSender(), toClaim);
     }

    // ***************** OWNER FUNCTIONS  *****************

     /**
     * @notice Update the contract claimer
     */
     function updateContractClaimer(address newClaimer) external {
        require(_msgSender() == contractClaimer, 'Not contract claimer');
        contractClaimer = newClaimer;
     }

     // ***************** HELPER FUNCTIONS  *****************

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

    /**
     * @dev Helper function to remove a tokenID from an array
     * @param tokenId ID of token to remove
     * @param array Array to remove the token from
     */
    function _removeToken(uint16 tokenId, uint16[] storage array) internal {
        uint16 tokenIndex = 2023;
        for (uint16 i = 0; i <= array.length; i++) {
            if (array[i] == tokenId){
                tokenIndex = i;
                break;
            }
        }
        require(tokenIndex < 2023, 'Token not found in array');
        for (uint16 i = tokenIndex; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
    }

}