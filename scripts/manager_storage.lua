CARD_STORAGE_PATH = "deckbox.storage";
CARD_ORIGIN_PATH = "origin"

-- Indexed by the token string, contains the DB node in storage
local _storage =  {};

function onInit()
	if Session.IsHost then
		local storage = DB.createNode(CARD_STORAGE_PATH);
		DB.deleteChildren(storage);
		storage.setPublic(true);
	end
end

-----------------------------------------------------
-- EVENT FUNCTIONS
-----------------------------------------------------

---Adds a card to card storage. Raises the onAddedToStorage event
---@param vCard databasenode|string
---@param tEventTrace table Event trace table
---@return databasenode card The node that was added to card storage
function addCardToStorage(vCard, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	if CardStorage.isCardInStorage(vCard) then
		local storageCard = CardStorage.getCardFromStorage(vCard);
		
		-- Update the card's origin every time we re-get it
		CardStorage.setCardOrigin(storageCard, vCard.getNodeName());

		return storageCard;
	end

	local newCard = DB.copyNode(vCard, DB.createChild(CardStorage.getCardStorageNode()));
	local sToken = CardsManager.getCardFront(vCard);

	-- We don't want card facing to be stored
	CardsManager.deleteFacingNode(newCard);

	-- We don't want node order to be stored
	CardsManager.deleteCardOrder(newCard);

	-- Save the actual location of the card so that we can drag/drop from this entry
	-- This is a crude way of getting cards back from the discard
	CardStorage.setCardOrigin(newCard, vCard.getNodeName());

	_storage[sToken] = newCard;

	tEventTrace = DeckedOutEvents.raiseOnCardAddedToStorageEvent(newCard, tEventTrace);

	return newCard;
end

-----------------------------------------------------
-- HELPERS
-----------------------------------------------------

---Checks of a card is already in storage
---@param vCard databasenode|string
---@return boolean
function isCardInStorage(vCard)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local sToken = CardsManager.getCardFront(vCard);
	return _storage[sToken] ~= nil;
end

---Gets a card from storage. Returns nil if card is not in storage
---@param vCard databasenode|string
---@return string tokenPrototype
function getCardFromStorage(vCard)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local sToken = CardsManager.getCardFront(vCard);

	return _storage[sToken];
end

---Checks if a card node comes from the card storage node
---@param vCard databasenode|string
---@return boolean
function doesCardComeFromStorage(vCard)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local sNodeName = vCard.getNodeName();
	return StringManager.startsWith(sNodeName, CardStorage.CARD_STORAGE_PATH);
end

---Gets the card storage node
---@return string
function getCardStorageNode()
	return DB.findNode(CardStorage.CARD_STORAGE_PATH);
end

---Sets the origin value of a card that's in storage
---@param storageCardNode databasenode
---@param sOrigin string
function setCardOrigin(storageCardNode, sOrigin)
	DB.setValue(storageCardNode, CardStorage.CARD_ORIGIN_PATH, "string", sOrigin); 
end

---Gets the origin value for a card that's in storage
---@param vCard databasenode|string
---@return string
function getCardOrigin(vCard)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.getValue(vCard, CardStorage.CARD_ORIGIN_PATH, "");
end

---Gets the origin node for a card that's in card storage
---@param vCard databasenode|string
---@returns databasenode cardnode
function getCardOriginNode(vCard)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.findNode(CardStorage.getCardOrigin(vCard));
end

---Checks if the origin for a card in storage is a discard pile
---@param vCard databasenode|string
---@return boolean
function isCardOriginADiscardPile(vCard)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local sOrigin = CardStorage.getCardOrigin(vCard);
	return string.find(sOrigin, "." .. DeckManager.DECK_DISCARD_PATH .. ".") ~= nil;
end