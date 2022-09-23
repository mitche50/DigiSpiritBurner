// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import './Adventure/DigiDaigakuSpirits.sol';
import './Adventure/DigiDaigaku.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DigiSpiritBurner is AdventurePermissions {

    DigiDaigaku genesisToken = DigiDaigaku(0xd1258DB6Ac08eB0e625B75b371C023dA478E94A9);
    DigiDaigakuSpirits spiritToken = DigiDaigakuSpirits(0xa8824EeE90cA9D2e9906D377D36aE02B1aDe5973);
    ERC20 weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    uint256 public heroFee;

    mapping(uint16 => bool) public genesisDeposited;
    mapping(uint16 => address) private _genesisOwner;

    mapping(uint16 => address) private _spiritOwner;
    mapping(uint16 => uint16) private _heroId;

    event GenesisDeposited(uint16 tokenId, address owner);
    event GenesisWithdrawn(uint16 tokenId, address owner);
    event SpiritDeposited(uint16 tokenId, address owner);
    event HeroMinted(uint16 spiritId, address owner);


    constructor(uint256 fee) {
        heroFee = fee;
    }

    /**
     * @notice Helper function to determine if a tokenId is mythic genesis
     * @param tokenId ID of genesis token
     */
     function _isMythic(uint16 tokenId) internal pure returns (bool){
        return (tokenId == 1632 || tokenId == 1938 || tokenId == 628 || tokenId == 379 || tokenId == 974);
     }

    /**
     * @notice Deposits genesis token into contract for "purposes"
     * @param tokenId ID of genesis token to deposit
     */
    function depositGenesis(uint16 tokenId) external {
        genesisToken.transferFrom(_msgSender(), address(this), tokenId);
        _genesisOwner[tokenId] = _msgSender();
        genesisDeposited[tokenId] = true;

        emit GenesisDeposited(tokenId, _msgSender());
    }

    /**
     * @notice Withdraw Genesis token
     * @param tokenId ID of the genesis token to be withdrawn
     */
    function withdrawGenesis(uint16 tokenId) external {
        require(_msgSender() == _genesisOwner[tokenId], "Not original owner of genesis");
        genesisToken.transferFrom(address(this), _msgSender(), tokenId);
        _genesisOwner[tokenId] = address(0);
        genesisDeposited[tokenId] = false;

        emit GenesisWithdrawn(tokenId, _msgSender());
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
    function withdrawSpirit(uint16 tokenId) external {
        require(_msgSender() == _spiritOwner[tokenId], "Not original owner of spirit");
        spiritToken.transferFrom(address(this), _msgSender(), tokenId);
    }

    /**
     * @notice Mint a hero from the provided token ID.  
     * @dev Requires the sender to be the original owner of the NFT, a genesis token to be in the contract
     * @dev and the user to have approved the contract to spend wETH fee
     * @param spiritId ID of the spirit token to be burnt for a hero
     * @param genesisId ID of the genesis token to be used
     */
    function mintHero(uint16 spiritId, uint16 genesisId) external {
        require(_msgSender() == _spiritOwner[spiritId], "Only Owner of spirit NFT can mint");
        require(genesisDeposited[genesisId], "Genesis not in contract");

        // If minting from a mythic, 10x hero minting fee
        uint256 finalFee = heroFee;
        if (_isMythic(genesisId)){
            finalFee *= 10;
        }
        
        // Transfer wETH Fee to Genesis Holder
        weth.transferFrom(_msgSender(), _genesisOwner[genesisId], heroFee);
        
        //TODO: confirm correct function to use
        spiritToken.adventureBurn(spiritId);

        //TODO: Assign minted hero to _heroId to original spirit ID or transfer minted hero token to _msgSender();
    }
}
