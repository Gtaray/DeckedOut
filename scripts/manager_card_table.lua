-- This manager is concerned with tracking cards that are placed on images

-- Design considerations
-- Cards dropped on images should be stored in a DB list, and they should point to the image they're on and their token id
-- Playing cards should send the appropriate message to chat
-- Double clicking (or middle-clicking with Natural Selection) should flip the token face up for face down (with the appropriate message in chat)
-- IF POSSIBLE there should be a new radial menu option for flip/grab/delete
-- Deleting the token should discard the card
-- Grabbing the link to a card that's on an image from chat should move the card from the image to the player's hand
	-- New chat message about "X picked up Y"
-- Update the moveCard function so that it keeps card facing when moved to a card table

CARD_TABLE_PATH = "deckbox.table";
CARD_TABLE_IMAGE_PATH = "image";
CARD_TABLE_ID_PATH = "tokenid";

local _tCardTable = {};

function onInit()
	Token.onDelete = CardTable.onTokenDeletedFromImage;
	ImageManager.registerDropCallback("shortcut", DeckedOutEvents.onCardDroppedOnImage);
end

function initializeCardTable()
	_tCardTable = {};
	for _, node in pairs(DB.getChildren(CARD_TABLE_PATH)) do
		local sImage = CardTable.getCardImage(node);
		local nId = CardTable.getCardTokenId(node);

		-- Only add if both were found.
		-- Though if these AREN'T found then there's some kind of error and
		-- we should probably handle that
		if sImage ~= "" and nId >= 0 then
			_tCardTable[sImage][nId] = node;
		end
	end
end

-----------------------------------------------------
-- EVENTS HANDLERS
-----------------------------------------------------

---Event for when a card token is dropped on an image
---@param cImageControl imagecontrol Image control the token is dropped on
---@param x number x coordinate of the drop location
---@param y number y coordinate of the drop location
---@param draginfo dragdata Dragdata information
---@return boolean bEndEvent If the return is true, the event is handled.
function onCardDroppedOnImage(cImageControl, x, y, draginfo)
	local sClass,sRecord = draginfo.getShortcutData();
	-- Only handle card drops
	if sClass ~= "card" then
		return false;
	end

	-- if the card comes from storage, we need to get it from its origin
	if CardStorage.doesCardComeFromStorage(vCard) then
		vCard = CardStorage.getCardOriginNode(vCard);
	end

	local vCard = DeckedOutUtilities.validateCard(sRecord);
	if not vCard then return false; end;

	local sCardBack = CardsManager.getCardBack(vCard);
	
	-- whether we place a card face down or face up is a bit tricky
	-- If the card was dragged from its source with the hotkey pressed and is thus face down
	-- then we always want to place face down
	-- If the card was dragged from its source face up, then we want to place the card
	-- respecting whether the facedown hotkey is currently pressed upon dropping
	local sToken = draginfo.getTokenData();
	local bFacedown = sToken == sCardBack;

	if DeckedOutUtilities.getFacedownHotkey() then
		sToken = sCardBack;
		bFacedown = true;
	end

	if sToken then
		local token = cImageControl.addToken(sToken, x, y)
		TokenManager.autoTokenScale(token);

		CardTable.addCardToTable(vCard, bFacedown, token);
		CardsManager.playCard(sRecord, bFacedown, DeckedOutUtilities.shouldPlayAndDiscard(sRecord), {})

		return token ~= nil;
	end
end

function onTokenDeletedFromImage(token)

	local nodeImage = token.getContainerNode();
	local sImage = DB.getPath(nodeImage);
	local nId = token.getId();

	-- Only process further if the token that was deleted maps to something
	-- that's in the card table
	if _tCardTable[sImage][nId] then
		CardTable.removeCardFromTable(sImage, nId, {})
	end
end

-----------------------------------------------------
-- EVENT RAISERS
-----------------------------------------------------

---Adds a card to the card table and track's it for as long as it's on an image
---@param vCard databasenode|string
---@param bFacedown boolean Is the card face up or face down
---@param token tokeninstance tokeninstance of the card after adding it to the image
---@param tEventTrace table Event trace table
---@return databasenode newCard The card's location after moving
function addCardToTable(vCard, bFacedown, token, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local nId = token.getId();
	local imagenode = token.getContainerNode();
	local sImagePath = DB.getPath(imagenode);
	local tablecard = vCard;

	-- If the card isn't on the table, then we go through the process of adding it
	-- if it IS on the table, we don't do any moving, we just update the origin values afterwards
	if not CardStorage.isCardOnTable(vCard) then		
		local tablenode = CardTable.getCardTableNode();

		tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedoutEvents.DECKEDOUT_EVENT_PUT_ON_TABLE);
		tablecard = CardsManager.moveCard(vCard, tablenode, tEventTrace)
	else
		-- If we're already on the table then we need to remove current data in the card table
		_tCardTable[sImagePath][nId] = nil;
	end

	-- Save the location of the card (imagenode path and token id)
	-- so that we can get it back later
	CardTable.udpateCardOnTable(tablecard, imagenode, nId);
	
	tEventTrace = DeckedOutEvents.raiseOnCardAddedToImageEvent(tablecard, imagenode, nId, tEventTrace);

	return newCard;
end

---Remvoes a card from the card table and discards it
---@param sImage string image node path of the image that the card was deleted from
---@param nId number token id of the card token that was deleted
---@param tEventTrace table event trace table
---@return databasenode cardInDiscard card node in the discard pile. Note if a client calls this function it will return nil
function removeCardFromTable(sImage, nId, tEventTrace)
	local cardNode = _tCardTable[sImage][nId];
	_tCardTable[sImage][nId] = nil;

	local bFacedown = CardsManager.isCardFaceDown(cardNode);

	tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_IMAGE_CARD_DELETED);
	local cardInDiscard = CardsManager.discardCard(cardNode, bFacedown, nil, tEventTrace);
	DeckedOutEvents.raiseOnCardDeletedFromImageEvent(cardInDiscard, tEventTrace);

	return cardInDiscard;
end

------------------------------------------
-- DATA MANAGEMENT
------------------------------------------

---Gets the node in which all cards on images are stored i.e. the card table
---@return databasenode
function getCardTableNode()
	return DB.createNode(CARD_TABLE_PATH);
end

---Checks of a card is already in storage
---@param vCard databasenode|string
---@return boolean
function isCardOnTable(vCard)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return StringManager.startsWith(DB.getPath(vCard), CARD_TABLE_PATH);
end

---Gets a card's node from the card table DB list
---@param vCard databasenode|string
---@return databasenode cardnode Node of the card on a table
function getCardOnTable(vCard)
end

---Updates a card's values in the card table to track it's current location
---@param vCard databasenode|string the card in the card table to be udpated
---@param imagenode databasenode the node of the image that the card is on
---@param nTokenId number the id of the tokeninstance that represents the card on its image
---@return boolean success true if operation succeeded, false if not
function updateCardOnTable(vCard, imagenode, nTokenId)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false; end

	-- Double check that we're updating a card in the card table
	if not CardTable.isCardOnTable(vCard) then
		return false;
	end

	local sImagePath = DB.getPath(imagenode);

	if not _tCardTable[sImagePath] then
		_tCardTable[sImagePath] = {};
	end
	_tCardTable[sImagePath][nTokenId] = vCard;

	DB.setValue(vCard, CARD_TABLE_IMAGE_PATH, "string", sImagePath);
	DB.setValue(vCard, CARD_TABLE_ID_PATH, "number", nTokenId);

	return true;
end

---Deletes the image node path and token id nodes from a card
---@param vCard databasenode|string
---@return boolean deleted
function deleteCardTableNodesFromCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false; end

	if not CardTable.isCardOnTable(vCard) then
		return false;
	end

	DB.deleteChild(vCard, CardTable.CARD_TABLE_IMAGE_PATH);
	DB.deleteChild(vCard, CardTable.CARD_TABLE_ID_PATH);

	return true;
end

---Gets the image node path of a card that's on the card table
---@param vCard databasenode|string
---@return string sImagePath or an empty string if no value is found
function getCardImage(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	if not CardTable.isCardOnTable(vCard) then
		return;
	end

	return DB.getValue(vCard, CardTable.CARD_TABLE_IMAGE_PATH, "");
end

---Gets the token id of a card that's on the card table
---@param vCard databasenode|string
---@return number tokenId or -1 if no value is found
function getCardTokenId(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	if not CardTable.isCardOnTable(vCard) then
		return;
	end

	return DB.getValue(vCard, CardTable.CARD_TABLE_ID_PATH, -1);
end