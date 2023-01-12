GM_HAND_PATH = "gmhand";
PLAYER_HAND_PATH = "cards";
CARD_FACING_PATH = "faceup";

OOB_MSGTYPE_DROPCARD = "dropcard";
OOB_MSGTYPE_DISCARD = "discard"
OOB_MSGTYPE_PUTCARDBACKINDECK = "putcardbackindeck";

function onInit()
	OOBManager.registerOOBMsgHandler(CardsManager.OOB_MSGTYPE_DROPCARD, handleCardDrop);
	OOBManager.registerOOBMsgHandler(CardsManager.OOB_MSGTYPE_DISCARD, handleDiscard);
	OOBManager.registerOOBMsgHandler(CardsManager.OOB_MSGTYPE_PUTCARDBACKINDECK, handlePutCardBackInDeck);
end

------------------------------------------
-- COMMON FUNCTIONS
------------------------------------------

---Moves a card from one place to another. Raises the onCardMoved event
---@param vCard databasenode|string
---@param vDestination databasenode Node under which the card node is moved to
---@param tEventTrace table Event trace table
---@return databasenode cardNode The card node in its new location
function moveCard(vCard, vDestination, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end

	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	vDestination = DeckedOutUtilities.validateNode(vDestination, "vDestination");
	if not vDestination then return end

	local sOldCardNode = vCard.getNodeName();
	local newNode = DB.createChild(vDestination);
	DB.copyNode(vCard, newNode);
	vCard.delete();

	-- if the card was moved to anywhere other than a hand, delete the facing node
	if not CardsManager.isCardInHand(newNode) then
		CardsManager.deleteFacingNode(newNode);
	end

	tEventTrace = DeckedOutEvents.raiseOnCardMovedEvent(newNode, sOldCardNode, tEventTrace);
	return newNode;
end

---Adds a card to an identity's hand. Raises the onCardAddedToHand event
---@param vCard databasenode|string
---@param sIdentity string Character identity (or 'gm') for the person receiving the card
---@param bFacedown boolean Should this card be facedown in the player's hand. This doesn't change
---@param tEventTrace table Event trace table
---@return databasenode cardNode The card node in its new location
function addCardToHand(vCard, sIdentity, bFacedown, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end;
	local handNode = DeckedOutUtilities.validateHandNode(sIdentity);
	if not handNode then return end

	if bFacedown then
		CardsManager.setCardFaceDown(vCard)
	else
		CardsManager.setCardFaceUp(vCard);
	end

	tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_ADDED_TO_HAND);
	local card = CardsManager.moveCard(vCard, handNode, tEventTrace);

	DeckedOutEvents.raiseOnCardAddedToHandEvent(card, sIdentity, bFacedown, tEventTrace);
	
	return card;
end

---Discards the given card from wherever it is located. 
---If a client calls this function, an OOB message is generated and sent 
---to the host to perform the actual moving of the databasenode.
---Raises the onCardDiscarded event
---@param vCard databasenode|string
---@param bFacedown boolean Is the card discarded face down
---@param sIdentity string Character identity or ('gm') for the person discarding the card.
---@param tEventTrace table Event trace table
function discardCard(vCard, bFacedown, sIdentity, tEventTrace)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	-- If a client is here, we need an OOB.
	if not Session.IsHost then
		sendDiscardMsg(vCard, bFacedown, User.getCurrentIdentity(), tEventTrace);
		return;
	end

	local vDeck = DeckedOutUtilities.validateDeck(CardsManager.getDeckIdFromCard(vCard));
	if not vDeck then
		-- If there's no vDeck present, then this could be a case of a dead card
		-- Check to see if it's other data is empty, and if so, delete it.
		if (CardsManager.getCardFront(vCard) or "") == "" then
			vCard.delete();
			return;
		end
	end

	-- If for some reason identity is nil, set to GM, since only the GM can get to this point in the functions
	if (sIdentity or "") == "" then
		sIdentity = "gm";
	end

	local discardNode = DeckManager.getDiscardNode(vDeck);
	if DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_DISCARD_TO_DECK) == "yes" then
		discardNode = DeckManager.getCardsNode(vDeck);
	end

	tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_DISCARDED);
	local card = CardsManager.moveCard(vCard, discardNode, tEventTrace);
	DeckedOutEvents.raiseOnDiscardFromHandEvent(card, sIdentity, bFacedown, tEventTrace);
end

---Discards a character's entire hand. Raises the onHandDiscarded event
---@param sIdentity string Character identity (or 'gm') for the person discarding their hand
---@param tEventTrace table Event trace table
function discardHand(sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	tEventTrace = DeckedOutEvents.raiseOnHandDiscardedEvent(sIdentity, nil, tEventTrace);

	for k,card in pairs(CardsManager.getHandNode(sIdentity).getChildren()) do
		CardsManager.discardCard(card, true, sIdentity, tEventTrace);
	end
end

---Discards all cards in a charaters hand that originated from a specific deck.
---Raises the onHandDiscarded event
---@param vDeck databasenode|string Deck whose cards should be discarded
---@param sIdentity string Character identity (or 'gm') for the person discarding their hand
---@param tEventTrace table Event trace table
function discardCardsInHandFromDeck(vDeck, sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	tEventTrace = DeckedOutEvents.raiseOnHandDiscardedEvent(sIdentity, vDeck, tEventTrace);

	sDeckId = DeckManager.getDeckId(vDeck);
	for k,card in pairs(CardsManager.getHandNode(sIdentity).getChildren()) do
		if CardsManager.getDeckIdFromCard(card) == sDeckId then
			CardsManager.discardCard(card, false, sIdentity, tEventTrace);
		end
	end
end

---Puts a card back into its deck
---@param vCard databasenode
---@param bFacedown boolean
---@param tEventTrace table
function putCardBackInDeck(vCard, bFacedown, tEventTrace)
	vCard = DeckedOutUtilities.validateCard(vCard)
	if not vCard then return end

	-- If we're not the host, then we need to send an OOB
	if not Session.IsHost then
		CardsManager.sendPutCardBackInDeckMsg(vCard, bFacedown, tEventTrace);
		return;
	end

	local vDeck = CardsManager.getDeckNodeFromCard(vCard);
	if not DeckedOutUtilities.validateDeck(vDeck) then return end

	local sIdentity = CardsManager.getCardSource(vCard);
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_PUT_BACK_IN_DECK);
	local card = CardsManager.moveCard(vCard, DeckManager.getCardsNode(vDeck), tEventTrace)
	if card then
		tEventTrace = DeckedOutEvents.raiseOnCardReturnedToDeckEvent(card, vDeck, sIdentity, {});
	end
end

---Puts all cards in a character's hand back into the appropriate decks.
---Raises the onHandReturnedToDeck event
---@param sIdentity string Character identity (or 'gm') for the person performing this action
---@param tEventTrace table Event trace table
function putHandBackIntoDeck(sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	if not DeckedOutItilities.validateIdentity(sIdentity) then return end

	tEventTrace = DeckedOutEvents.raiseOnHandReturnedToDeckEvent(sIdentity, nil, tEventTrace)

	for k,card in pairs(CardsManager.getHandNode(sIdentity).getChildren()) do
		local vDeck = DeckedOutUtilities.validateDeck(CardsManager.getDeckIdFromCard(card));
		if vDeck then
			local cardAfterMoved = CardsManager.moveCard(card, DeckManager.getCardsNode(vDeck), tEventTrace)
		end
	end
end

---Returns all cards in a person's hand of a given deck
---Raises the onHandReturnedToDeck event
---@param vDeck databasenode|string Deck node whose cards should be returned to the deck
---@param sIdentity string Character identity (or 'gm') of the actor performing this action
---@param tEventTrace table Even trace table
function putCardsFromDeckInHandBackIntoDeck(vDeck, sIdentity, tEventTrace) 
	if not DeckedOutUtilities.validateHost() then return end
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	tEventTrace = DeckedOutEvents.raiseOnHandReturnedToDeckEvent(sIdentity, vDeck, tEventTrace)

	for k,card in pairs(CardsManager.getHandNode(sIdentity).getChildren()) do
		local deckid = CardsManager.getDeckIdFromCard(card);
		local deckNode = DB.findNode(deckid)
		if deckNode and deckid == sDeckId then
			CardsManager.moveCard(card, DeckManager.getCardsNode(deckNode), tEventTrace)
		end
	end
end

---Plays a card face up or face down. Depending on the settings for the card's deck, it will discard the card afterwards
-- Raises the onCardPlayed event
---@param vCard databasenode|string
---@param bFacedown boolean default true
---@param tEventTrace table
function playCard(vCard, bFacedown, bDiscard, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local vDeck = DeckedOutUtilities.validateDeck(CardsManager.getDeckNodeFromCard(vCard));
	if not vDeck then return end

	DeckedOutEvents.raiseOnCardPlayedEvent(vCard, bFacedown, bDiscard, tEventTrace)

	if bDiscard then
		local sIdentity = CardsManager.getCardSource(vCard);
		CardsManager.discardCard(vCard, bFacedown, sIdentity, tEventTrace);
	else
		-- The most minor of optimizations
		-- Don't flip the card face up if it's getting discarded
		CardsManager.setCardFaceUp(vCard);
	end
end

---Gets a random card from sIdentity's hand and plays it
---@param sIdentity string
---@param bFacedown boolean
---@param tEventTrace table
---@return databasenode cardPlayed
function playRandomCard(sIdentity, bFacedown, bDiscard, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	local aCards = CardsManager.getRandomCardsInHand(sIdentity, 1);

	if aCards and aCards[1] then
		-- tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_HAND_PLAY_RANDOM);
		DeckedOutEvents.raiseOnPlayRandomCardEvent(aCards[1], bFacedown, tEventTrace)
		CardsManager.playCard(aCards[1], bFacedown, bDiscard, tEventTrace);
		
	end
end

---Gets a random card from sIdentity's hand and discards it
---@param sIdentity string
---@param bFacedown boolean
---@param tEventTrace table
---@return databasenode cardPlayed
function discardRandomCard(sIdentity, bFacedown, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	local aCards = CardsManager.getRandomCardsInHand(sIdentity, 1);
	
	if aCards and aCards[1] then
		tEventTrace = DeckedOutEvents.raiseOnDiscardRandomCardEvent(aCards[1], sIdentity, bFacedown, nil, tEventTrace)
		CardsManager.discardCard(aCards[1], bFacedown, sIdentity, tEventTrace);
	end
end

---Gets a random card from sIdentity's hand that originates from vDeck, and discards it.
---@param vDeck databasenode
---@param sIdentity string
---@param bFacedown boolean
---@param tEventTrace table
function discardRandomCardFromDeck(vDeck, sIdentity, bFacedown, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	local aCards = CardsManager.getRandomCardsInHand(sIdentity, 1, vDeck);

	if aCards and aCards[1] then
		DeckedOutEvents.raiseOnDiscardRandomCardEvent(aCards[1], sIdentity, bFacedown, vDeck, tEventTrace)
		CardsManager.discardCard(aCards[1], bFacedown, sIdentity, tEventTrace);
	end
end

---Flips a card from face up to face down or visa versa
---@param vCard databasenode
function flipCardFacing(vCard, tEventTrace)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	if CardsManager.isCardFaceUp(vCard) then
		DeckedOutEvents.raiseOnCardFlippedEvent(vCard, CardsManager.getCardSource(vCard), 0, tEventTrace)
		CardsManager.setCardFaceDown(vCard);
	else
		DeckedOutEvents.raiseOnCardFlippedEvent(vCard, CardsManager.getCardSource(vCard), 1, tEventTrace)
		CardsManager.setCardFaceUp(vCard);
	end
end

------------------------------------------
-- HAND FUNCTIONS
------------------------------------------

---Gets the hand database node for a given identity
---@param sIdentity string Character identity (or 'gm')
---@return databasenode
function getHandNode(sIdentity)
	return DB.createNode(CardsManager.getHandPath(sIdentity));
end

---Returns the full DB path for an identity's hand node
---@param sIdentity string Character identity (or 'gm')
---@return string dbPath
function getHandPath(sIdentity)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	if sIdentity == "gm" then
		return CardsManager.GM_HAND_PATH;
	else
		return DB.getPath("charsheet", sIdentity, CardsManager.PLAYER_HAND_PATH);
	end
end

---Gets a list of all cards in an identity's hand
---@param sIdentity string Character identity (or 'gm')
---@return table cards A table of card database nodes, indexed by the node name
function getCardsInHand(sIdentity)
	local handNode = CardsManager.getHandNode(sIdentity);
	return DB.getChildren(handNode);
end

---Gets the number of cards in an identity's hand
---@param sIdentity string Character identity (or 'gm')
---@return number
function getNumberOfCardsInHand(sIdentity)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end
	return CardsManager.getHandNode(sIdentity).getChildCount();
end

---Gets the number of cards in an identity's hand that originate from a specific deck
---@param vDeck databasenode|string
---@param sIdentity string Character identity (or 'gm')
---@return number
function getNumberOfCardsFromDeckInHand(vDeck, sIdentity)
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	local nCount = 0;
	local sDeckId = DeckManager.getDeckId(vDeck);
	for k,card in pairs(CardsManager.getHandNode(sIdentity).getChildren()) do
		local deckid = CardsManager.getDeckIdFromCard(card);
		local deckNode = DB.findNode(deckid)
		if deckNode and deckid == sDeckId then
			nCount = nCount + 1;
		end
	end

	return nCount;
end

---Gets a number of randomly selected cards from an identity's hand
---@param sIdentity string
---@param nNumberOfCards number
---@return table aCards
function getRandomCardsInHand(sIdentity, nNumberOfCards, vDeck)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	local sDeckId = nil;
	if vDeck then
		sDeckId = DeckManager.getDeckId(vDeck);
	end

	local aCards = {};
	for k,v in pairs(CardsManager.getCardsInHand(sIdentity)) do
		if sDeckId then
			if CardsManager.getDeckIdFromCard(v) == sDeckId then
				table.insert(aCards, v);
			end
		else
			table.insert(aCards, v);
		end
	end

	if #aCards == 0 then
		return;
	end

	local aResults = {};
	for i = 1, nNumberOfCards, 1 do
		table.insert(aResults, table.remove(aCards, math.random(1, #aCards)));
	end

	return aResults;
end

------------------------------------------
-- MOVE CARD
------------------------------------------

---Internal use only. Makes sure that a card being put back in deck only happens on the host
---@param vCard databasenode
---@param bFacedown boolean
---@param tEventTrace table
function sendPutCardBackInDeckMsg(vCard, bFacedown, tEventTrace)
	local msg = {};
	msg.type = CardsManager.OOB_MSGTYPE_PUTCARDBACKINDECK;
	msg.sCardRecord = vCard.getNodeName();
	if bFacedown then
		msg.bFacedown = "true";
	else
		msg.bFacedown = "false";
	end

	if tEventTrace and #tEventTrace > 0 then
		for k,v in ipairs(tEventTrace or {}) do
			msg["trace_" .. k] = v;
		end
	end

	Comm.deliverOOBMessage(msg, "");
end

---Internal use only. Handles the put card back in deck message
---@param msgOOB table
function handlePutCardBackInDeck(msgOOB)
	-- Only the GM should handle this
	if not Session.IsHost then
		return;	
	end

	local tEventTrace = {};
	local i = 1;
	local key = "trace_" .. i;
	local value = msgOOB[key];
	while value ~= nil do
		tEventTrace[i] = value;
		i = i + 1;
		key = "trace_" .. i;
		value = msgOOB[key];
	end

	CardsManager.putCardBackInDeck(msgOOB.sCardRecord, msgOOB.bFacedown == "true", tEventTrace);
end

------------------------------------------
-- DISCARD
------------------------------------------

---Internal use only. Clients send this OOB message when they discard a card
---@param vCard databasenode Card being discarded
---@param bFacedown boolean
---@param sIdentity string Character identity (or 'gm')
---@param tEventTrace Event trace table
function sendDiscardMsg(vCard, bFacedown, sIdentity, tEventTrace)
	local msg = {};
	msg.type = CardsManager.OOB_MSGTYPE_DISCARD;
	msg.sCardRecord = vCard.getNodeName();
	msg.sSender = sIdentity;

	if tEventTrace and #tEventTrace > 0 then
		for k,v in ipairs(tEventTrace or {}) do
			msg["trace_" .. k] = v;
		end
	end

	Comm.deliverOOBMessage(msg, "");
end

---Internal use only. Receives the OOB message a client sends when they discard a card
---@param msgOOB table OOB message table
function handleDiscard(msgOOB)
	-- Only the GM should handle this
	if not Session.IsHost then
		return;	
	end

	local tEventTrace = {};
	local i = 1;
	local key = "trace_" .. i;
	local value = msgOOB[key];
	while value ~= nil do
		tEventTrace[i] = value;
		i = i + 1;
		key = "trace_" .. i;
		value = msgOOB[key];
	end

	CardsManager.discardCard(msgOOB.sCardRecord, msgOOB.bFacedown == "true", msgOOB.sSender, tEventTrace);
end

------------------------------------------
-- CARD STATES
------------------------------------------

---Checks if a card is currently located in a deck
---@param vCard databasenode|string
---@return boolean
function isCardInDeck(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local sNodeParentName = vCard.getChild("..").getName();
	return StringManager.startsWith(vCard.getNodeName(), "deckbox") and sNodeParentName == DeckManager.DECK_CARDS_PATH;
end

---Checks if a card is currently discarded
---@param vCard databasenode|string
---@return boolean
function isCardDiscarded(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local sNodeParentName = vCard.getChild("..").getName();
	return StringManager.startsWith(vCard.getNodeName(), "deckbox") and sNodeParentName == DeckManager.DECK_DISCARD_PATH;
end

---Checks if a card is currently in someone's hand
---@param vCard databasenode|string
---@return boolean
function isCardInHand(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return CardsManager.isCardOwnedByCharacter(vCard) or CardsManager.isCardOwnedByGm(vCard);
end

---Checks if a card is currently in a character's hand
---@param vCard databasenode|string
---@return boolean
function isCardOwnedByCharacter(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	return StringManager.startsWith(vCard.getNodeName(), "charsheet");
end

---Checks if a card is currently in the GM's hand
---@param vCard databasenode|string
---@return boolean
function isCardOwnedByGm(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	return StringManager.startsWith(vCard.getNodeName(), CardsManager.GM_HAND_PATH);
end

---Gets the full database path of the deck from which a card originates
---@param vCard databasenode|string
---@return string
function getDeckIdFromCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.getValue(vCard, "deckid", "");
end

---Gets the database node of the deck from which a card originates
---@param vCard databasenode|string
---@return databasenode
function getDeckNodeFromCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DeckedOutUtilities.validateDeck(CardsManager.getDeckIdFromCard(vCard));
end

---Gets the name of the deck from which a card originates
---@param vCard databasenode|string
---@return string
function getDeckNameFromCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.getValue(vCard, "deckname", "");
end

---Checks whether a card comes from a specific deck
---@param vDeck databasenode|string
---@param vCard databasenode|string
---@return boolean
function doesCardComeFromDeck(vDeck, vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return CardsManager.getDeckIdFromCard(vCard) == CardsManager.getDeckId(vDeck) and
		   CardsManager.getDeckNameFromCard(vCard) == CardsManager.getDeckName(vDeck);
end

---Gets the token prototype for the back of a card's deck
---@param vCard databasenode|string
---@return string sTokenPrototype
function getCardBack(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DeckManager.getDecksCardBack(CardsManager.getDeckIdFromCard(vCard));
end

---Gets the token prototype for a card
---@param vCard databasenode|string
---@return string sTokenPrototype
function getCardFront(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.getValue(vCard, "image", "");
end

---Gets the name of a card
---@param vCard databasenode|string
---@return string
function getCardName(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DB.getValue(vCard, "name", "");
end

---Gets the identity for the current holder of a card. If the card is in a 
---character's hand, this returns that character's identity. If the card is anywhere
---else, this returns 'gm'
---@param vCard databasenode|string
---@return string
function getCardSource(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	if CardStorage.doesCardComeFromStorage(vCard) then
		return "storage";
	end

	if CardsManager.isCardInHand(vCard) then
		if StringManager.startsWith(vCard.getNodeName(), "charsheet") then
			return vCard.getChild("...").getName();
		end
	end

	return "gm";
end

---Gets the resolved actor table for the owner of a card
---@param vCard databasenode|string
---@return table rActor
function getActorHoldingCard(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	if not CardsManager.isCardOwnedByCharacter(vCard) then
		return;
	end

	return ActorManager.resolveActor(vCard.getChild("..."));
end

---Checks if an actor is holding a card. Only works for PCs
---@param vCard databasenode|string
---@param rActor table
---@return boolean
function isActorHoldingCard(vCard, rActor)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	if not DeckedOutUtilities.validateParameter(rActor, "rActor") then return false end

	-- Check if the source is the GM or storage
	local sSource = CardsManager.getCardSource(vCard)
	if sSource == "gm" or sSource == "storage" then
		return false;
	end

	return rActor.sCreatureNode == DB.getPath("charsheet", sSource);
end

---Is card face down
---@param vCard databasenode
---@return boolean
function isCardFaceUp(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false end

	-- cards can only be facedown in hand. If the card isn't in a hand, then it's always face up
	if not CardsManager.isCardInHand(vCard) then
		return true;
	end

	return CardsManager.getCardFacing(vCard) == 1;
end

---Is Card Face up
---@param vCard databasenode
---@return boolean
function isCardFaceDown(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return false end

	-- cards can only be facedown in hand. If the card isn't in a hand, then it's always face up
	if not CardsManager.isCardInHand(vCard) then
		return false;
	end

	return CardsManager.getCardFacing(vCard) == 0;
end

---Gets the card facing number. 1 = face up, 0 = face down
---@param vCard databasenode
---@return integer facing
function getCardFacing(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return 0 end

	-- cards can only be facedown in hand. If the card isn't in a hand, then it's always face up
	if not CardsManager.isCardInHand(vCard) then
		return 1;
	end

	return DB.getValue(vCard, CardsManager.CARD_FACING_PATH, 1);
end

---Sets a card face up if it's in a hand
---@param vCard databasenode
function setCardFaceUp(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	CardsManager.setCardFacing(vCard, 1);
end

---Sets a card face down if it's in a hand
---@param vCard databasenode
function setCardFaceDown(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	CardsManager.setCardFacing(vCard, 0);
end

---Sets a card face up for face down
---@param vCard databasenode
---@param nFacing number. 0 = face down, 1 = face up
function setCardFacing(vCard, nFacing)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	-- if the card is in a hand, we can set the facing
	DB.setValue(vCard, CardsManager.CARD_FACING_PATH, "number", nFacing)
end

---Deletes the facup node for a card
---@param vCard databasenode
function deleteFacingNode(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	DB.deleteChild(vCard, CardsManager.CARD_FACING_PATH);
end
------------------------------------------
-- DRAG DROP
------------------------------------------

---Sets the token data for the draginfo when a card is dragged from a deck
---@param vDeck databasenode|string
---@param draginfo dragdata
function onDragFromDeck(vDeck, draginfo)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local vCard = DeckedOutUtilities.validateCard(DeckManager.drawCard(vDeck));
	if not vCard then return end

	CardsManager.onDragCard(vCard, draginfo);

	local bFacedown = DeckManager.dealFacedownByDefault(vDeck) 
					  or DeckedOutUtilities.getFacedownHotkey();

	if bFacedown then
		draginfo.setNumberData(0);
	else
		draginfo.setNumberData(1);
	end

	local sDealVisSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_DEAL_VISIBILITY);
	local bGmSeesFacedown = DeckManager.canGmSeeFacedownCards(vDeck);

	-- Check if the GM should see the card being dealt (which is separate from the card being dealt face down)
	if sDealVisSetting == "actor" or sDealVisSetting == "none" or (bFacedown and not bGmSeesFacedown) then
		draginfo.setTokenData(CardsManager.getCardBack(vCard));
	else
		draginfo.setTokenData(DB.getValue(vCard, "image", ""));
	end
end

---Initializes data when a token is dragged from somewhere.
---Sets the token data, the shortcut, and the description
---@param vCard databasenode|string
---@param draginfo dragdata
---@return boolean
function onDragCard(vCard, draginfo)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	if (CardsManager.getCardFront(vCard) or "") == "" then
		return true;
	end

	local bFacedown = DeckedOutUtilities.getFacedownHotkey();

	-- This determines whether the GM should see the card being dragged
	local bShowCardBack = bFacedown or CardsManager.isCardFaceDown(vCard);

	draginfo.setType("shortcut");
	draginfo.setShortcutData("card", vCard.getPath());

	-- The number data is used to determine whether cards should be dealt facedown
	-- which can be independent of the token that's displayed
	if bShowCardBack then
		draginfo.setTokenData(CardsManager.getCardBack(vCard));
		draginfo.setNumberData(0);
	else
		draginfo.setTokenData(DB.getValue(vCard, "image", ""));
		draginfo.setNumberData(1);
	end
	draginfo.setDescription(DB.getValue(vCard, "name", ""));
end

-- vDestination in this case should be the Node of the thing that's holding the card
-- i.e. the charsheet record. it should NOT be the charsheet.cards node
---Handles a card being dropped onto any particular destination. 
---Handles giving and playing cards
---@param draginfo dragdata
---@param vDestination databasenode|string Node for the location onto which the card is being dropped
---@param sExtra string If this is equal to DeckManager.DECK_DISCARD_PATH, then the card is sent to the deck's discard pile
---@return boolean
function onDropCard(draginfo, vDestination, sExtra)
	if not draginfo then
		Debug.console("ERROR: CardsManager.onDropCard(): draginfo was nil or not found.");
		return false;
	end
	local vDestination = DeckedOutUtilities.validateNode(vDestination, "vDestination");
	if not vDestination then return false end

	-- Only handle shortcut drops
	if not draginfo.isType("shortcut") then
		return false;
	end

	local sClass,sRecord = draginfo.getShortcutData();
	-- Only handle card drops
	if sClass ~= "card" then
		return false;
	end

	-- Figure out if the card should be passed facedown
	-- This happens before the card storage check because doing stuff
	-- from card storage will reset the facedown flag
	-- (since it doesn't preserve in storage)
	local bFacedown = draginfo.getNumberData() == 0;

	-- If this item was dragged from card storage (i.e. the chat) then do nothing
	-- Items in chat should never be moved or handled by anything, they're read only
	if CardStorage.doesCardComeFromStorage(sRecord) then
		-- Check the deck setting for the card to see if players are allowed
		-- to grab cards from chat. GMs can always do this, and they're allowed
		-- to grab from anywhere, not just discards
		local bAllowPlayerGrab = DeckManager.getDeckSetting(
			CardsManager.getDeckNodeFromCard(sRecord), 
			DeckManager.DECK_SETTING_PLAYERS_CAN_GRAB_DISCARDS) == "yes";

		-- Do all the negative checks first for ease of readability.
		if not Session.IsHost then
			if not bAllowPlayerGrab then
				Comm.addChatMessage( { font = "systemfont", text = "You are not allowed to grab cards from chat."});
				return false;
			end
			if not CardStorage.isCardOriginADiscardPile(sRecord) then
				Comm.addChatMessage( { font = "systemfont", text = "The card you are trying to drag from chat is not currently discarded."});
				return false;
			end
		end

		local cardnode = DB.findNode(CardStorage.getCardOrigin(sRecord));
		if cardnode then
			sRecord = cardnode.getNodeName();
			bFacedown = DeckedOutUtilities.getFacedownHotkey();
		else
			Comm.addChatMessage( { font = "systemfont", text = "The card you're trying to grab cannot be located." } );
			return false;
		end
	end

	sDestPath = vDestination.getNodeName();

	if not Session.IsHost then
		CardsManager.sendCardDropMessage(sRecord, sDestPath, sExtra, bFacedown);
		return true;
	end

	return CardsManager.handleAnyDrop(sRecord, sDestPath, sExtra, bFacedown);
end

---Handles dropping a card on any target
---@param sSourceNode string DB path id of the card being dropped
---@param sDestinationNode string DB path id of the location the card is being dropped on
---@param sExtra string If this is equal to DeckManager.DECK_DISCARD_PATH, then the card is sent to the deck's discard pile
---@return boolean
function handleAnyDrop(sSourceNode, sDestinationNode, sExtra, bFacedown)
	vCard = DeckedOutUtilities.validateNode(sSourceNode, "sSourceNode");
	vDestination = DeckedOutUtilities.validateNode(sDestinationNode, "sDestinationNode");
	if not (vCard and vDestination) then return false end
	
	local sDestination = "";
	local sReceivingIdentity = "";

	-- Dropped on a charater sheet
	if StringManager.startsWith(vDestination.getNodeName(), "charsheet") then
		-- If vDestination isn't the hand path, then get the hand path
		if vDestination.getName() ~= CardsManager.PLAYER_HAND_PATH then
			vDestination = CardsManager.getHandNode(vDestination.getName());
		end
		
		-- After the above, vDestination is the cards node for the character (charsheet.*.cards)
		sReceivingIdentity = vDestination.getParent().getName();

	elseif StringManager.startsWith(vDestination.getNodeName(), CardsManager.GM_HAND_PATH) then
		vDestination = CardsManager.getHandNode("gm");
		sReceivingIdentity = "gm"

	elseif StringManager.startsWith(vDestination.getNodeName(), "combattracker") then
		if ActorManager.isPC(vDestination) then
			-- If dropping on PC, give card to that PC
			sReceivingIdentity = ActorManager.getCreatureNode(vDestination).getName();
			vDestination = CardsManager.getHandNode(sReceivingIdentity);
		else
			-- If dropping on NPC, give card to GM
			vDestination = CardsManager.getHandNode("gm");
			sReceivingIdentity = "gm"
		end

	elseif StringManager.startsWith(vDestination.getNodeName(), "deckbox") then
		-- Check that the card being dropped belongs in this deck
		if CardsManager.getDeckIdFromCard(vCard) ~= DeckManager.getDeckId(vDestination) then
			Debug.console("WARNING: CardsManager.handleAnyDrop(): Tried to move a card to another deck.")
			return false;
		end

		-- Currently we only care about if sExtra for dropping on to the discard
		-- which currently thing does.
		if sExtra == DeckManager.DECK_DISCARD_PATH then
			vDestination = vDestination.getChild(DeckManager.DECK_DISCARD_PATH);
		else
			vDestination = vDestination.getChild(DeckManager.DECK_CARDS_PATH);
		end
	end

	-- Check if a the source of the card is the same as the destination
	-- and if it is, bail.
	local sourceParentNode = vCard.getParent();
	if sourceParentNode.getNodeName() == vDestination.getNodeName() then
		Debug.console("WARNING: CardsManager.handleAnyDrop(): Tried to move a card to the same place it originated from.")
		return true;
	end

	if vDestination then
		tEventTrace = {}; -- We have to new up the table here since dropping is guaranteed to be the first in any chain of events

		if (sReceivingIdentity or "") ~= "" then
			-- If the card being dropped is currently in a hand, then we fire the give event
			if CardsManager.isCardInHand(vCard) then
				local sGiverIdentity = CardsManager.getCardSource(vCard);
				tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_GIVEN);
				local card = CardsManager.addCardToHand(vCard, sReceivingIdentity, false, tEventTrace);
				DeckedOutEvents.raiseOnGiveCardEvent(card, sGiverIdentity, sReceivingIdentity, bFacedown, tEventTrace)
				return true;

			-- If the card being dropped is currently in a deck or discard pile, we fire the deal event
			elseif CardsManager.isCardInDeck(vCard) or CardsManager.isCardDiscarded(vCard) then
				-- Since we're dealing the card from a deck, we need to get the deck's default deal facing
				local bDefaultFacing = DeckManager.getDeckSetting(
					CardsManager.getDeckNodeFromCard(vCard), 
					DeckManager.DECK_SETTING_DEFAULT_DEAL_FACING)
				bFacedown = bFacedown or bDefaultFacing == "facedown";
				
				-- If we're fishing this card from the discard pile, then we want to raise a different event
				if CardsManager.isCardDiscarded(vCard) then
					tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_DEALT_FROM_DISCARD);
					local card = CardsManager.addCardToHand(vCard, sReceivingIdentity, bFacedown, tEventTrace);
					DeckedOutEvents.raiseOnCardDealtFromDiscardEvent(card, sReceivingIdentity, bFacedown, tEventTrace)
				else	
					tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_DEALT);
					local card = CardsManager.addCardToHand(vCard, sReceivingIdentity, bFacedown, tEventTrace);
					DeckedOutEvents.raiseOnDealCardEvent(card, sReceivingIdentity, bFacedown, tEventTrace)
				end
				return true;
			end
		else
			if StringManager.startsWith(vDestination.getNodeName(), "deckbox") then
				-- We dropped onto the deck, so we fire the return to deck event
				if vDestination.getName() == DeckManager.DECK_CARDS_PATH then
					local sGiverIdentity = CardsManager.getCardSource(vCard);
					DeckedOutEvents.raiseOnCardReturnedToDeckEvent(
						vCard, 
						CardsManager.getDeckNodeFromCard(vCard), 
						sGiverIdentity, 
						bFacedown,
						tEventTrace);
					CardsManager.moveCard(vCard, vDestination, tEventTrace);
					return true;
				elseif vDestination.getName() == DeckManager.DECK_DISCARD_PATH then
					local sGiverIdentity = CardsManager.getCardSource(vCard);
					local card = discardCard(vCard, bFacedown, sGiverIdentity, tEventTrace);
				end
			else
				local card = CardsManager.moveCard(vCard, vDestination, tEventTrace);
				return true;
			end
		end
	end

	return false;
end

---Internal use only. Sends an OOB message to handle onDrop events. Only called by clients
---@param sSourceNode string
---@param sDestinationNode string
---@param sExtra string
function sendCardDropMessage(sSourceNode, sDestinationNode, sExtra, bFacedown)
	-- The GM shouldn't be here, only clients should be sending this message
	if Session.IsHost then
		return;
	end

	local msgOOB = {};
	msgOOB.type = CardsManager.OOB_MSGTYPE_DROPCARD;
	msgOOB.sSourceNode = sSourceNode;
	msgOOB.sDestinationNode = sDestinationNode;
	msgOOB.sExtra = sExtra;
	if bFacedown then
		msgOOB.bFacedown = "true";
	else
		msgOOB.bFacedown = "false";
	end

	Comm.deliverOOBMessage(msgOOB, "");
end

---Internal use only. Receives an OOB message to handle onDrop events
---@param msgOOB table
function handleCardDrop(msgOOB)
	-- Only the GM should be handling drops, becuase this usually means moving around data
	-- Which only the GM can do anyway
	if not Session.IsHost then
		return;
	end

	CardsManager.handleAnyDrop(msgOOB.sSourceNode, msgOOB.sDestinationNode, msgOOB.sExtra, msgOOB.bFacedown == "true");
end