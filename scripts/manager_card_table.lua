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

-- Okay, so trying to keep the DB list in synch with a table that maps imagenode and token id 
-- to card DB node is really messy and kind of overcomplicating things
-- The only place that gives any performance is when doing lookups when a person double clicks a token,
-- or deletes a token (and possibly when they claim a card to put in their hand)
-- All of those are user actions, so it's unlikely the performance hit will be noticable
-- unless there are hundreds or thousands of card tokens on a map. And even then, there are bigger problems
-- So I think I'm going to remove _tCardTable from here and rely solely on the DB

CARD_TABLE_PATH = "deckbox.table";
CARD_TABLE_IMAGE_PATH = "isonimage";
CARD_TABLE_ID_PATH = "tokenid";

-- Used to flag when a card is being flipped
-- because if a card is being flipped, we don't 
-- want to discard when it's deleted
local _bFlipping = false;
local _fAutoTokenScale;

function onInit()
	Token.onDrop = DeckedOutEvents.onCardDroppedOnToken;
	Token.onDelete = CardTable.onCardDeletedFromImage;
	Token.onDoubleClick = CardTable.onCardDoubleClicked;
	ImageManager.registerDropCallback("shortcut", CardTable.onCardDroppedOnImage);

	_fAutoTokenScale = TokenManager.autoTokenScale;
	TokenManager.autoTokenScale = CardTable.autoTokenScale;
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
	if sClass ~= "deckedout_card" then
		return false;
	end

	vCard = DeckedOutUtilities.validateCard(sRecord);
	if not vCard then return false; end;

	if not Session.IsHost then
		-- Send an OOB so that host can do the actual card drop
	end

	-- if the card comes from storage, we need to get it from its origin
	if CardStorage.doesCardComeFromStorage(sRecord) then
		vCard = CardStorage.getCardOriginNode(sRecord);
	end

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

		local newCard = CardTable.playCardOnTable(vCard, bFacedown, token, {});
		CardTable.updateTokenName(newCard, token);

		return token ~= nil;
	end
end

---Event for when a card token is deleted from an image. Discards the card
---@param token tokeninstance token being deleted
function onCardDeletedFromImage(token)
	if _bFlipping then
		return false;
	end

	-- Only process further if the token that was deleted maps to something
	-- that's in the card table
	local cardnode = CardTable.getCardFromToken(token);
	if cardnode then
		CardTable.discardCardFromTable(cardnode, {})
		return true;
	end
end

---Event for when a card is double-clicked on an image. Flips the card
---@param token tokeninstance
---@param image imagecontrol
function onCardDoubleClicked(token, image)
	if not Session.IsHost then
		-- Send an OOB so that host can do the actual flipping
		-- local sIdentity = User.getCurrentIdentity();
	end

	local cardnode = CardTable.getCardFromToken(token)
	if not cardnode then
		return;
	end


	CardTable.flipCardOnTable(token, image, cardnode, "gm");

	return true;
end

function autoTokenScale(tokenMap)
	-- If we're flipping a card we absolutely do not want the token auto scaled
	if _bFlipping then
		return;
	end

	_fAutoTokenScale(tokenMap);
end

-----------------------------------------------------
-- EVENT RAISERS
-----------------------------------------------------

---Plays a card on to an image track's it for as long as it's there
---@param vCard databasenode|string
---@param bFacedown boolean Is the card face up or face down
---@param token tokeninstance tokeninstance of the card after adding it to the image
---@param tEventTrace table Event trace table
---@return databasenode newCard The card's location after moving
function playCardOnTable(vCard, bFacedown, token, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local nId = token.getId();
	local imagenode = token.getContainerNode();
	local sImagePath = DB.getPath(imagenode);
	local tablecard = vCard;

	-- If the card isn't on the table, then we go through the process of adding it
	-- if it IS on the table, we don't do any moving, we just update the origin values afterwards
	if not CardTable.isCardOnTable(vCard) then		
		local tablenode = CardTable.getCardTableNode();

		tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_PUT_ON_TABLE);
		tablecard = CardsManager.moveCard(vCard, tablenode, tEventTrace)
	end

	-- Save the location of the card (imagenode path and token id)
	-- so that we can get it back later
	CardTable.updateCardOnTable(tablecard, imagenode, nId, bFacedown);
	
	tEventTrace = DeckedOutEvents.raiseOnCardAddedToImageEvent(tablecard, tEventTrace);

	return tablecard;
end

---Remvoes a card from the card table and discards it
---@param vCard databasenode|string
---@param tEventTrace table event trace table
---@return databasenode cardInDiscard card node in the discard pile. Note if a client calls this function it will return nil
function discardCardFromTable(vCard, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local bFacedown = CardsManager.isCardFaceDown(vCard);

	tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_IMAGE_CARD_DELETED);
	local cardInDiscard = CardsManager.discardCard(vCard, bFacedown, nil, tEventTrace);
	DeckedOutEvents.raiseOnCardDeletedFromImageEvent(cardInDiscard, tEventTrace);

	return cardInDiscard;
end

---Flips a card face up or face down
---@param token tokeninstance
---@param image imagecontrol
---@param cardnode databasenode
---@param sIdentity string identity (or 'gm') of the person doing the flipping
function flipCardOnTable(token, image, cardnode, sIdentity)
	_bFlipping = true;

	local nScale = token.getScale()

	-- First update the node backing the token
	CardsManager.flipCardFacing(cardnode, sIdentity, {})

	local sNewToken = CardsManager.getCardFacingImage(cardnode);

	-- Have to be careful here, because deleting a tokeninstance will trigger the discard
	-- and there's no other way to change the token's prototype after it's on an image
	local x, y = token.getPosition();
	-- local newToken = image.addToken(sNewToken, x, y);
	local newToken = Token.addToken(DB.getPath(token.getContainerNode()), sNewToken, x, y);
	newToken.setScale(nScale)
	newToken.setOrientation(token.getOrientation());
	CardTable.updateTokenName(cardnode, newToken);
	token.delete();

	-- This is crucial, because the new token has a new id, and we need to update
	-- the DB with the new token id.
	CardTable.setCardTokenId(cardnode, newToken.getId());
	
	_bFlipping = false;
end

------------------------------------------
-- DATA MANAGEMENT
------------------------------------------

---Gets the node in which all cards on images are stored i.e. the card table
---@return databasenode
function getCardTableNode()
	return DB.createNode(CARD_TABLE_PATH);
end

---Gets an iterator for easy use in for loops
---@return fun(table: table<<string>, <databasenode>>, index?: <K>):<K>, <V>
function getCardTableIterator()
	return pairs(DB.getChildren(DB.getPath(CardTable.CARD_TABLE_PATH)))
end

---Checks of a card is already in storage
---@param vCard databasenode|string
---@return boolean
function isCardOnTable(vCard)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false; end

	return StringManager.startsWith(DB.getPath(vCard), CardTable.CARD_TABLE_PATH);
end

---Gets a card based on a tokeninstance
---@param token tokeninstance
---@return databasenode cardnode or nil if token is not a card node
function getCardFromToken(token)
	local nTokenId = token.getId();
	local sImageNode = DB.getPath(token.getContainerNode());

	for _, cardnode in CardTable.getCardTableIterator() do
		local image = CardTable.getCardImage(cardnode);
		local id = CardTable.getCardTokenId(cardnode);

		if image == sImageNode and id == nTokenId then
			return cardnode;	
		end
	end

end

---Checks if a token is a card token
---@param token tokeninstance
---@return boolean
function isTokenCard(token)
	return getCardFromToken(token) ~= nil;
end

---Updates a card's values in the card table to track it's current location
---@param vCard databasenode|string the card in the card table to be udpated
---@param imagenode databasenode the node of the image that the card is on
---@param nTokenId number the id of the tokeninstance that represents the card on its image
---@return boolean success true if operation succeeded, false if not
function updateCardOnTable(vCard, imagenode, nTokenId, bFacedown)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false; end

	-- Double check that we're updating a card in the card table
	if not CardTable.isCardOnTable(vCard) then
		return false;
	end

	local sImagePath = DB.getPath(imagenode);
	local nFacing = 1; -- default to face up
	if bFacedown then
		nFacing = 0;
	end

	CardTable.setCardImage(vCard, sImagePath);
	CardTable.setCardTokenId(vCard, nTokenId);
	CardsManager.setCardFacing(vCard, nFacing);

	return true;
end

function deleteCardFromCardTable(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false; end

	if not CardTable.isCardOnTable(vCard) then
		return false;
	end

	local sImage = CardTable.getCardImage(card);
	local nId = CardTable.getCardTokenId(card);
end

---Deletes the image node path and token id nodes from a card
---@param vCard databasenode|string
---@return boolean deleted
function deleteCardTableNodesFromCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false; end

	-- Make sure that we're not deleting card table nodes for a card that's 
	-- currently on the card table
	if CardTable.isCardOnTable(vCard) then
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
	if not vCard then return ""; end

	if not CardTable.isCardOnTable(vCard) then
		return "";
	end

	return DB.getValue(vCard, CardTable.CARD_TABLE_IMAGE_PATH, "");
end

---Sets the image path for cards that are on the card table
---@param vCard databasenode|string
---@param sImagePath string DB node path to the image the card is one
---@return boolean success true if successful, false if not.
function setCardImage(vCard, sImagePath)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false; end

	DB.setValue(vCard, CardTable.CARD_TABLE_IMAGE_PATH, "string", sImagePath);

	return true;
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

---Sets the token id for cards that are on the card table
---@param vCard databasenode|string
---@param nTokenId number token id of the card on the table
---@return boolean success true if successful, false if not.
function setCardTokenId(vCard, nTokenId)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false; end

	DB.setValue(vCard, CardTable.CARD_TABLE_ID_PATH, "number", nTokenId);

	return true;
end

---Updates a card token's name based on whetehr the card is face up for face down
---@param vCard databasenode|string
---@param token tokeninstance
function updateTokenName(vCard, token)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	if CardsManager.isCardFaceDown(vCard) then
		token.setName(CardsManager.getDeckNameFromCard(vCard));
	else
		token.setName(CardsManager.getCardName(vCard));
	end
end