GM_HAND_PATH = "gmhand";
PLAYER_HAND_PATH = "cards";

OOB_MSGTYPE_DROPCARD = "dropcard";
OOB_MSGTYPE_DISCARD = "discard"

function onInit()
	OOBManager.registerOOBMsgHandler(CardManager.OOB_MSGTYPE_DROPCARD, handleCardDrop);
	OOBManager.registerOOBMsgHandler(CardManager.OOB_MSGTYPE_DISCARD, handleDiscard);
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

	tEventTrace = DeckedOutEvents.raiseOnCardMovedEvent(newNode, sOldCardNode, tEventTrace);
	return newNode;
end

---Adds a card to an identity's hand. Raises the onCardAddedToHand event
---@param vCard databasenode|string
---@param sIdentity string Character identity (or 'gm') for the person receiving the card
---@param tEventTrace table Event trace table
---@return databasenode cardNode The card node in its new location
function addCardToHand(vCard, sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end;
	local handNode = DeckedOutUtilities.validateHandNode(sIdentity);
	if not handNode then return end

	tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_ADDED_TO_HAND);
	local card = CardManager.moveCard(vCard, handNode, tEventTrace);
	DeckedOutEvents.raiseOnCardAddedToHandEvent(card, sIdentity, tEventTrace);
	
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

	local vDeck = DeckedOutUtilities.validateDeck(CardManager.getDeckIdFromCard(vCard));
	if not vDeck then
		-- If there's no vDeck present, then this could be a case of a dead card
		-- Check to see if it's other data is empty, and if so, delete it.
		if (CardManager.getCardFront(vCard) or "") == "" then
			vCard.delete();
			return;
		end
	end

	-- If for some reason identity is nil, set to GM, since only the GM can get to this point in the functions
	if (sIdentity or "") == "" then
		sIdentity = "gm";
	end

	tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_DISCARDED);
	local card = CardManager.moveCard(vCard, DeckManager.getDiscardNode(vDeck), tEventTrace);
	DeckedOutEvents.raiseOnDiscardFromHandEvent(card, sIdentity, bFacedown, tEventTrace);
end

---Discards a character's entire hand. Raises the onHandDiscarded event
---@param sIdentity string Character identity (or 'gm') for the person discarding their hand
---@param tEventTrace table Event trace table
function discardHand(sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	tEventTrace = DeckedOutEvents.raiseOnHandDiscardedEvent(sIdentity, nil, tEventTrace);

	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		CardManager.discardCard(card, true, sIdentity, tEventTrace);
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
	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		if CardManager.getDeckIdFromCard(card) == sDeckId then
			CardManager.discardCard(card, false, tEventTrace);
		end
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

	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		local vDeck = DeckedOutUtilities.validateDeck(CardManager.getDeckIdFromCard(card));
		if vDeck then
			CardManager.moveCard(card, DeckManager.getCardsNode(vDeck), tEventTrace)
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

	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		local deckid = CardManager.getDeckIdFromCard(card);
		local deckNode = DB.findNode(deckid)
		if deckNode and deckid == sDeckId then
			CardManager.moveCard(card, DeckManager.getCardsNode(deckNode), tEventTrace)
		end
	end
end

---Plays a card face up or face down. Depending on the settings for the card's deck, it will discard the card afterwards
-- Raises the onCardPlayed event
---@param vCard databasenode|string
---@param bFacedown boolean default true
---@param tEventTrace table
function playCard(vCard, bFacedown, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local vDeck = DeckedOutUtilities.validateDeck(CardManager.getDeckNodeFromCard(vCard));
	if not vDeck then return end

	local bDiscard = false;
	if CardManager.isCardInHand(vCard) then
		bDiscard = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_AUTO_PLAY_FROM_HAND) == "yes";
	elseif CardManager.isCardInDeck(vCard) then
		bDiscard = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_AUTO_PLAY_FROM_DECK) == "yes";
	end

	-- The hotkey should take presedence over any other options.
	if DeckedOutUtilities.getPlayAndDiscardHotkey() then
		bDiscard = true;
	end

	DeckedOutEvents.raiseOnCardPlayedEvent(vCard, bFacedown, bDiscard, tEventTrace)

	if bDiscard then
		local sIdentity = CardManager.getCardSource(vCard);
		CardManager.discardCard(vCard, bFacedown, sIdentity, tEventTrace);
	end
end

------------------------------------------
-- HAND FUNCTIONS
------------------------------------------

---Gets the hand database node for a given identity
---@param sIdentity string Character identity (or 'gm')
---@return databasenode
function getHandNode(sIdentity)
	return DB.createNode(CardManager.getHandPath(sIdentity));
end

---Returns the full DB path for an identity's hand node
---@param sIdentity string Character identity (or 'gm')
---@return string dbPath
function getHandPath(sIdentity)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	if sIdentity == "gm" then
		return CardManager.GM_HAND_PATH;
	else
		return DB.getPath("charsheet", sIdentity, CardManager.PLAYER_HAND_PATH);
	end
end

---Gets a list of all cards in an identity's hand
---@param sIdentity string Character identity (or 'gm')
---@return table cards A table of card database nodes, indexed by the node name
function getCardsInHand(sIdentity)
	local handNode = CardManager.getHandNode(sIdentity);
	return DB.getChildren(handNode);
end

---Gets the number of cards in an identity's hand
---@param sIdentity string Character identity (or 'gm')
---@return number
function getNumberOfCardsInHand(sIdentity)
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end
	return CardManager.getHandNode(sIdentity).getChildCount();
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
	for k,card in pairs(CardManager.getHandNode(sIdentity).getChildren()) do
		local deckid = CardManager.getDeckIdFromCard(card);
		local deckNode = DB.findNode(deckid)
		if deckNode and deckid == sDeckId then
			nCount = nCount + 1;
		end
	end

	return nCount;
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
	msg.type = CardManager.OOB_MSGTYPE_DISCARD;
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

	CardManager.discardCard(msgOOB.sCardRecord, msgOOB.bFacedown == "true", msgOOB.sSender, tEventTrace);
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

	return CardManager.isCardOwnedByCharacter(vCard) or CardManager.isCardOwnedByGm(vCard);
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
	return StringManager.startsWith(vCard.getNodeName(), CardManager.GM_HAND_PATH);
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

	return DeckedOutUtilities.validateDeck(CardManager.getDeckIdFromCard(vCard));
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

	return CardManager.getDeckIdFromCard(vCard) == CardManager.getDeckId(vDeck) and
		   CardManager.getDeckNameFromCard(vCard) == CardManager.getDeckName(vDeck);
end

---Gets the token prototype for the back of a card's deck
---@param vCard databasenode|string
---@return string sTokenPrototype
function getCardBack(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	return DeckManager.getDecksCardBack(CardManager.getDeckIdFromCard(vCard));
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

	if CardManager.isCardInHand(vCard) then
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

	if not CardManager.isCardOwnedByCharacter(vCard) then
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
	local sSource = CardManager.getCardSource(vCard)
	if sSource == "gm" or sSource == "storage" then
		return false;
	end

	return rActor.sCreatureNode == DB.getPath("charsheet", sSource);
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

	CardManager.onDragCard(vCard, draginfo);

	if DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_DEAL_VISIBILITY) == "actor" then
		-- If only the person receiving the card should see the card, then we replace the image
		-- That's dragged with the back image
		draginfo.setTokenData(CardManager.getCardBack(vCard));
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

	if (CardManager.getCardFront(vCard) or "") == "" then
		return true;
	end

	draginfo.setType("shortcut");
	draginfo.setShortcutData("card", vCard.getPath());
	if DeckedOutUtilities.getFacedownHotkey() then
		draginfo.setTokenData(CardManager.getCardBack(vCard));
	else
		draginfo.setTokenData(DB.getValue(vCard, "image", ""));
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
		Debug.console("ERROR: CardManager.onDropCard(): draginfo was nil or not found.");
		return;
	end
	local vDestination = DeckedOutUtilities.validateNode(vDestination, "vDestination");
	if not vDestination then return end

	-- Only handle shortcut drops
	if not draginfo.isType("shortcut") then
		return;
	end

	local sClass,sRecord = draginfo.getShortcutData();
	-- Only handle card drops
	if sClass ~= "card" then
		return;
	end

	-- If this item was dragged from card storage (i.e. the chat) then do nothing
	-- Items in chat should never be moved or handled by anything, they're read only
	if CardStorage.doesCardComeFromStorage(sRecord) then
		Debug.console("WARNING: Tried to drag/drop a card from chat. Card links in chat cannot be moved and are read-only.");
		return;
	end

	sDestPath = vDestination.getNodeName();

	if not Session.IsHost then
		CardManager.sendCardDropMessage(sRecord, sDestPath, sExtra);
		return true;
	end

	return CardManager.handleAnyDrop(sRecord, sDestPath, sExtra);
end

---Handles dropping a card on any target
---@param sSourceNode string DB path id of the card being dropped
---@param sDestinationNode string DB path id of the location the card is being dropped on
---@param sExtra string If this is equal to DeckManager.DECK_DISCARD_PATH, then the card is sent to the deck's discard pile
---@return boolean
function handleAnyDrop(sSourceNode, sDestinationNode, sExtra)
	vCard = DeckedOutUtilities.validateNode(sSourceNode, "sSourceNode");
	vDestination = DeckedOutUtilities.validateNode(sDestinationNode, "sDestinationNode");
	if not (vCard and vDestination) then return false end
	
	local sDestination = "";
	local sReceivingIdentity = "";

	-- Dropped on a charater sheet
	if StringManager.startsWith(vDestination.getNodeName(), "charsheet") then
		-- If vDestination isn't the hand path, then get the hand path
		if vDestination.getName() ~= CardManager.PLAYER_HAND_PATH then
			vDestination = CardManager.getHandNode(vDestination.getName());
		end
		
		-- After the above, vDestination is the cards node for the character (charsheet.*.cards)
		sReceivingIdentity = vDestination.getParent().getName();

	elseif StringManager.startsWith(vDestination.getNodeName(), CardManager.GM_HAND_PATH) then
		vDestination = CardManager.getHandNode("gm");
		sReceivingIdentity = "gm"

	elseif StringManager.startsWith(vDestination.getNodeName(), "combattracker") then
		if ActorManager.isPC(vDestination) then
			-- If dropping on PC, give card to that PC
			sReceivingIdentity = ActorManager.getCreatureNode(vDestination).getName();
			vDestination = CardsManager.getHandNode(sReceivingIdentity);
		else
			-- If dropping on NPC, give card to GM
			vDestination = CardManager.getHandNode("gm");
			sReceivingIdentity = "gm"
		end

	elseif StringManager.startsWith(vDestination.getNodeName(), "deckbox") then
		-- Check that the card being dropped belongs in this deck
		if CardManager.getDeckIdFromCard(vCard) ~= DeckManager.getDeckId(vDestination) then
			Debug.console("WARNING: CardManager.handleAnyDrop(): Tried to move a card to another deck.")
			return;
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
		Debug.console("WARNING: CardManager.handleAnyDrop(): Tried to move a card to the same place it originated from.")
		return true;
	end

	if vDestination then
		tEventTrace = {}; -- We have to new up the table here since dropping is guaranteed to be the first in any chain of events

		if (sReceivingIdentity or "") ~= "" then
			-- If the card being dropped is currently in a hand, then we fire the give event
			if CardManager.isCardInHand(vCard) then
				local sGiverIdentity = CardManager.getCardSource(vCard);
				tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_GIVEN);
				local card = CardManager.addCardToHand(vCard, sReceivingIdentity, tEventTrace);
				DeckedOutEvents.raiseOnGiveCardEvent(card, sGiverIdentity, sReceivingIdentity, tEventTrace)
				return true;

			-- If the card being dropped is currently in a deck or discard pile, we fire the deal event
			elseif CardManager.isCardInDeck(vCard) or CardManager.isCardDiscarded(vCard) then
				tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_DEALT);
				local card = CardManager.addCardToHand(vCard, sReceivingIdentity, tEventTrace);
				DeckedOutEvents.raiseOnDealCardEvent(card, sReceivingIdentity, tEventTrace)
				return true;
			end
		else
			local card = CardManager.moveCard(vCard, vDestination, tEventTrace);
			return true;
		end
	end

	return false;
end

---Internal use only. Sends an OOB message to handle onDrop events. Only called by clients
---@param sSourceNode string
---@param sDestinationNode string
---@param sExtra string
function sendCardDropMessage(sSourceNode, sDestinationNode, sExtra)
	-- The GM shouldn't be here, only clients should be sending this message
	if Session.IsHost then
		return;
	end

	local msgOOB = {};
	msgOOB.type = CardManager.OOB_MSGTYPE_DROPCARD;
	msgOOB.sSourceNode = sSourceNode;
	msgOOB.sDestinationNode = sDestinationNode;
	msgOOB.sExtra = sExtra;

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

	CardManager.handleAnyDrop(msgOOB.sSourceNode, msgOOB.sDestinationNode, msgOOB.sExtra);
end