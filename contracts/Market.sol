// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "@openzeppelin/contracts/access/Ownable.sol";


/*
 Simple ERC1155 marketplace. It represents in-game items, so each option corresponds to an game item, like: Skin, Weapon, Armor.
 
 The features:
 - admin can add new items to the marketplace (provides ipfs metadata url, name, price, max supply)
 - admin can change price for each item
 - users can purchase item if minter didn't run out of supply and if saleStarted = true
 - users can list item for sale
 - users can buy items from other users
 - admin can withdraw funds from sale, but 10% goes to the developer address "0x704C043CeB93bD6cBE570C6A2708c3E1C0310587"
 - tokens are burnable
 - admin can flipSaleStarted, switching between sale active or disabled (saleStarted is true/false)
 Items are stored in array of struct GameItem.
 In ERC1155, tokens have id, which represents itemId.
 */
contract Market is ERC1155Holder, Ownable {

    // ERC1155 contract
    IERC1155 public immutable tokenContract;

    // Address for fee
    address payable buildship = payable(0x704C043CeB93bD6cBE570C6A2708c3E1C0310587);

    mapping (uint256 => Offer[]) public offers;


    struct Offer {
        uint256 price;
        // uint256 itemId;
        uint256 amount;
        address payable owner;
    }

    // users can purchase item if minter didn't run out of supply and if saleStarted = true
    // users can list item for sale
    // users can buy items from other users

    // admin can change price for each item
    // users can purchase item if minter didn't run out of supply and if saleStarted = true
    // users can list item for sale
    // users can buy items from other users
    // admin can withdraw funds from sale, but 10% goes to the developer address "0x704C043CeB93bD6cBE570C6A2708c3E1C0310587"

    constructor (IERC1155 _tokenContract) {
        require(_tokenContract.supportsInterface(type(IERC1155).interfaceId), "Token is not supported");
        tokenContract = _tokenContract;
    }
    
    //add offer to the list
    function addItemToList(uint256 tokenId, uint256 amount, uint256 price) public {
        require(tokenContract.balanceOf(msg.sender, tokenId) >= amount, "Not enough tokens");
        require(tokenContract.isApprovedForAll(msg.sender, address(this)), "Cant list for sale if not approved for all");
        
        bool offerExists = false;
        uint256 unusedOffer = 2^256 - 1;
        for (uint256 i = 0; i < offers[tokenId].length; i++) {
            if (offers[tokenId][i].owner == msg.sender && offers[tokenId][i].amount > 0) {
                offerExists = true;
                break;
            }

            if (offers[tokenId][i].amount == 0) {
                unusedOffer = i;
            }
        }

        require(offerExists == false, 'Offer Already Exists! Please choose function updateItemFromList');

        Offer memory offer = Offer(price, amount, payable(msg.sender));
        
        if (unusedOffer == 2^256 - 1) {
            offers[tokenId].push(offer);
        } else {
            offers[tokenId][unusedOffer] = offer;
        }  
    }

    // update offer from the list
    function updateOfferFromList(uint256 tokenId, uint256 amount, uint256 price) public {
        require(tokenContract.balanceOf(msg.sender, tokenId) >= amount, "Not enough tokens");
        require(tokenContract.isApprovedForAll(msg.sender, address(this)), "Cant list for sale if not approved for all");

        uint256 offerId = 2^256 - 1;
        for (uint256 i = 0; i < offers[tokenId].length; i++) {
            if (offers[tokenId][i].owner == msg.sender && offers[tokenId][i].amount > 0) {
                offerId = i;
                break;
            }
        }

        require(offerId != 2^256 - 1, "You haven't offer with this tokenId");

        Offer memory offer = Offer(price, amount, payable(msg.sender));
        offers[tokenId][offerId] = offer;
    }

    // delete offer from the list
    function deleteOfferFromList(uint256 tokenId) public {
        uint256 offerId = 2^256 - 1;
        for (uint256 i = 0; i < offers[tokenId].length; i++) {
            if (offers[tokenId][i].owner == msg.sender && offers[tokenId][i].amount > 0) {
                offerId = i;
                break;
            }
        }

        require(offerId != 2^256 - 1, "You haven't offer with this tokenId");
        offers[tokenId][offerId].amount = 0;
    }

    function buy(uint256 tokenId, uint256 offerId, uint256 amount) payable public {
        Offer storage offer = offers[tokenId][offerId];

        require(amount >= 0, "Amount should be more than 0");
        require(offer.amount >= amount, "Not enough tokens");
        require(msg.value >= offer.price * amount, "Not enough ETH");

        // CHECK APPROVE
        if(!tokenContract.isApprovedForAll(offer.owner, address(this))) {
            offer.amount = 0;
            require(false, "Cant buy, offer is not valid");
        }

        // CHECK IF AMOUNT OF OFFER LESS THAN AMOUNT OF SELLER
        if (tokenContract.balanceOf(offer.owner, tokenId) < offer.amount) {
            offer.amount = 0;
            require(false, "Offer have been deleted, amount of offer less than amount of seller");
        }

        // Transfer tokens to user
        offer.amount -= amount;
        tokenContract.safeTransferFrom(offer.owner, msg.sender, tokenId, amount, "");

        uint256 fee = offer.price * amount * 7 / 100;
        uint256 rest = msg.value - offer.price * amount;

        // Transfer Fee
        (bool success,) = buildship.call{value: fee}("");
        require(success);
        
        // Transfer to seller
        offer.owner.transfer(offer.price * amount - fee);

        // Transfer Rest
        payable(msg.sender).transfer(rest);
    }

}