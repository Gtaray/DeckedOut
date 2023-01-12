DECKEDOUT_EVENT_CARD_PLAYED = "cardplayed";
DECKEDOUT_EVENT_CARD_DISCARDED = "carddiscarded";
DECKEDOUT_EVENT_CARD_GIVEN = "cardgiven";
DECKEDOUT_EVENT_CARD_DEALT = "carddealt";
DECKEDOUT_EVENT_DEALT_FROM_DISCARD = "dealtfromdiscard";
DECKEDOUT_EVENT_CARD_ADDED_TO_STORAGE = "cardaddedtostorage";
DECKEDOUT_EVENT_CARD_MOVED = "cardmoved";
DECKEDOUT_EVENT_CARD_PUT_BACK_IN_DECK = "cardputbackindeck";
DECKEDOUT_EVENT_CARD_ADDED_TO_HAND = "cardaddedtohand";
DECKEDOUT_EVENT_CARD_FLIPPED = "cardflipped"
DECKEDOUT_EVENT_CARD_PEEK = "cardpeek";
DECKEDOUT_EVENT_MULTIPLE_CARDS_DEALT = "multiplecardsdealt";
DECKEDOUT_EVENT_GROUP_DEAL = "groupdeal";

DECKEDOUT_EVENT_HAND_GIVE_RANDOM = "giverandom";
DECKEDOUT_EVENT_HAND_PLAY_RANDOM = "playrandom";
DECKEDOUT_EVENT_HAND_DISCARD_RANDOM = "discardrandom";
DECKEDOUT_EVENT_HAND_DISCARDED = "handdiscarded";
DECKEDOUT_EVENT_HAND_PUT_BACK_IN_DECK = "handputbackindeck"

DECKEDOUT_EVENT_DECK_CREATED = "deckcreated";
DECKEDOUT_EVENT_DECK_DELETED = "deckdeleted";

DECKEDOUT_EVENT_IMAGE_CARD_ADDED = "cardaddedtoimage"; -- Currently not used
DECKEDOUT_EVENT_IMAGE_CARD_DELETED = "carddeletedfromimage"; -- Currently not used

DECKEDOUT_EVENT_DECK_SETTING_CHANGED = "decksettingchanged";

OOB_MSGTYPE_DECKEDOUTEVENT = "deckedoutevent";

function onInit()
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_DECK_DELETED, { fCallback = deleteCardsFromDecksThatAreDeleted, target="host" });

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_DECKEDOUTEVENT, DeckedOutEvents.raiseEventHandler);
	ChatManager.registerDropCallback("shortcut", DeckedOutEvents.onCardDroppedInChat);
	ImageManager.registerDropCallback("shortcut", DeckedOutEvents.onCardDroppedOnImage);

	Token.onDrop = DeckedOutEvents.onCardDroppedOnToken;
	Interface.onHotkeyDrop = DeckedOutEvents.onCardDroppedOnHotkey;

	DB.addHandler("deckbox.decks.*", "onDelete", onDeckDeleted);
	DB.addHandler("deckbox.decks.*", "onAdd", onDeckAdded);
end

function onClose()
	DB.removeHandler("deckbox.decks.*", "onDelete", onDeckDeleted);
	DB.removeHandler("deckbox.decks.*", "onAdd", onDeckAdded);
end

function onDeckDeleted(nodeDeck)
	DeckedOutEvents.raiseOnDeckDeletedEvent(nodeDeck, {})
end

function onDeckAdded(nodeDeck)
	DeckedOutEvents.raiseOnDeckCreatedEvent(nodeDeck, {})
end

local _tEvents = {};
-----------------------------------------------------
-- EVENT REGISTRATION
-----------------------------------------------------
---@class eventData
---@field fCallback function The function that is called when the event is raised
---@field target string "host", "client", "immediate", or nil. Specifies where this callback will occur. Immediate will happen without an OOB message being sent.

---@class eventMessage
---@field type string OOB Message type
---@field event string Event key to raise
---@field args table Table of event arguments.
---@field trace table Table for the event trace.

---Registers an event. 
---@param sEventKey string
---@param tEventData eventData 
function registerEvent(sEventKey, tEventData)
	if not _tEvents[sEventKey] then
		_tEvents[sEventKey] = {};
	end

	table.insert(_tEvents[sEventKey], tEventData);
end

---Raises an event, which either sends an OOB message or fire the event handler immmediately.
---@param sEventKey string Event key for the event to raise
---@param tArgs table Table of arguments that is passed to the event
---@param tEventTrace table Integer indexed table of event keys that representing events that have been raised as part of a single user action.
---@param bDontAddTrace boolean Flag for whether to add this event to the event trace. Used when you manually add an event to the trace
---@return table tEventTrace Returns the tEventTrace table with the current event added to it 
function raiseEvent(sEventKey, tArgs, tEventTrace, bDontAddTrace)
	if not tEventTrace then
		tEventTrace = {};
	end

	if not bDontAddTrace then
		tEventTrace = addEventTrace(tEventTrace, sEventKey);
	end

	local event = _tEvents[sEventKey];
	if event then
		-- Build OOB message
		msg = {};
		msg.type = DeckedOutEvents.OOB_MSGTYPE_DECKEDOUTEVENT;
		msg.event = sEventKey;
		msg.args = {};
		msg.trace = {};

		for k,v in pairs(tArgs) do
			msg["args_" .. k] = v;
		end
		for k,v in pairs(tEventTrace) do
			msg["trace_" .. k] = v;
		end

		-- if the event is immediate, just sent the message directly, otherwise send an OOB
		if event.target == "immediate" then
			DeckedOutEvents.raiseEventHandler(msg);
		else
			Comm.deliverOOBMessage(msg);
		end
	end

	return tEventTrace
end

---Handles the deckedoutevent OOB message. Runs any event handlers for the event
---@param msg eventMessage OOB message handler
function raiseEventHandler(msg)
	local sEventKey = msg.event;
	local args = {};
	local trace = {};

	for k,v in pairs(msg) do
		local type,key = string.match(k, "([^_]*)_(.*)");
		if type == "args" then
			args[key] = v;
		elseif type == "trace" then
			trace[tonumber(key)] = v;
		end
	end

	if _tEvents[sEventKey] then
		for k,eventdata in ipairs(_tEvents[sEventKey]) do
			if (eventdata.sTarget == "host" and Session.IsHost) or 
			   (eventdata.sTarget == "client" and (not Session.IsHost)) or
			   ((eventdata.sTarget or "") == "") then
				eventdata.fCallback(args, trace);
			end
		end
	end
end

---Adds an entry to the event table
---@param tEventTrace table Integer indexed table of event keys that representing events that have been raised as part of a single user action.
---@param sEventKey string Event key for the event to raise
---@return table tEventTrace Returns the tEventTrace table with the current event added to it 
function addEventTrace(tEventTrace, sEventKey)
	if not tEventTrace then
		tEventTrace = {};
	end
	table.insert(tEventTrace, sEventKey);
	return tEventTrace;
end

-----------------------------------------------------
-- EVENT RAISERS
-----------------------------------------------------

---Raises the onCardPlayed event
---@param vCard databasenode Card that is being played 
---@param bFacedown boolean Is this card being played facedown?
---@param bDiscard boolean Is this card being discarded after being played?
---@param tEventTrace table Event trace table
---@return table tEventTrace Event trace table
function raiseOnCardPlayedEvent(vCard, bFacedown, bDiscard, tEventTrace)
	local tArgs = { sCardNode = vCard.getNodeName() };
	tArgs.bFacedown = "false";
	if bFacedown then
		tArgs.bFacedown = "true";
	end

	tArgs.bDiscard = "false";
	if bDiscard then
		tArgs.bDiscard = "true";
	end
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_PLAYED,
		tArgs,
		tEventTrace
	);
end

---Raises the onCardMoved event.
---@param vCard databasenode Card that is moved, AFTER the move takes place.
---@param sOldCardNode string DB path for where the card came from BEFORE the move takes place.
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnCardMovedEvent(vCard, sOldCardNode, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_MOVED, 
		{ sCardNode = vCard.getNodeName(), sOldCardNode = sOldCardNode },
		tEventTrace
	);
end

---Raises the onCardMoved event.
---@param vCard databasenode Card that is added to hand, AFTER is is added to the hand
---@param sIdentity string Character identity (or 'gm') of the person whose hand the card is being added to
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnCardAddedToHandEvent(vCard, sIdentity, bFacedown, tEventTrace)
	local tArgs = { sCardNode = vCard.getNodeName(), sIdentity = sIdentity, bFacedown = "false" };
	if bFacedown then
		tArgs.bFacedown = "true";
	end

	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_ADDED_TO_HAND, 
		tArgs,
		tEventTrace,
		true -- True because this event technically happens after moveCard, and by then the trace is already updated
	);
end

---Raises the onCardDiscard event
---@param vCard databasenode Card being discarded, AFTER the move takes place
---@param sIdentity string Character identity (or 'gm') of the person discarding the card
---@param bFacedown boolean Is the card being discarded facedown?
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnDiscardFromHandEvent(vCard, sIdentity, bFacedown, tEventTrace)
	local tArgs = { sCardNode = vCard.getNodeName(), sSender = sIdentity };
	if bFacedown then
		tArgs.bFacedown = "true";
	end
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_DISCARDED, 
		tArgs,
		tEventTrace,
		true
	);
end

---Raises the onGiveRandomCard event
---@param vCard databasenode Card that's being givem
---@param sGiverIdentity string Character identity (or 'gm') for the person giving the card
---@param sReceiverIdentity string Character identity (or 'gm') for the person receiving the card
---@param bFacedown boolean
---@param tEventTrace table
---@return table tEventTrace
function raiseOnGiveRandomCardEvent(vCard, sGiverIdentity, sReceiverIdentity, bFacedown, tEventTrace)
	local tArgs = { sCardNode = vCard.getNodeName(), sGiver = sGiverIdentity, sReceiver = sReceiverIdentity };
	if bFacedown then
		tArgs.bFacedown = "true";
	end

	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_HAND_GIVE_RANDOM,
		tArgs,
		tEventTrace,
		true
	)
end

---Raises the onPlayRandomCard event
---@param vCard databasenode Card that is being played 
---@param bDiscard boolean Is this card being discarded after being played?
---@param tEventTrace table Event trace table
---@return table tEventTrace Event trace table
function raiseOnPlayRandomCardEvent(vCard, bFacedown, tEventTrace)
	local tArgs = { sCardNode = vCard.getNodeName() };
	tArgs.bFacedown = "false";
	if bFacedown then
		tArgs.bFacedown = "true";
	end
	
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_HAND_PLAY_RANDOM,
		tArgs,
		tEventTrace
	)
end

---Raises the onDiscardRandomCard event
---@param vCard databasenode Card being discarded, AFTER the move takes place
---@param sIdentity string Character identity (or 'gm') of the person discarding the card
---@param bFacedown boolean Is the card being discarded facedown?
---@param vDeck databasenode optional. Deck from which the card in hand is being discarded
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnDiscardRandomCardEvent(vCard, sIdentity, bFacedown, vDeck, tEventTrace)
	local tArgs = { sCardNode = vCard.getNodeName(), sSender = sIdentity };
	if bFacedown then
		tArgs.bFacedown = "true";
	end
	if vDeck then
		tArgs.sDeckNode = vDeck.getNodeName();
	end
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_HAND_DISCARD_RANDOM, 
		tArgs,
		tEventTrace
	);
end

-- sIdentity: identity of the user whose hand to discard
-- sDeckNode: optional. If present, specifies that only cards from this deck were discarded
---Raises the onHandSicarded event.
---@param sIdentity string Character identity (or 'gm') of the person discarding their hand
---@param vDeck databasenode optional. Deck node for which cards should be discarded
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnHandDiscardedEvent(sIdentity, vDeck, tEventTrace)
	local tArgs = { sIdentity = sIdentity };
	if vDeck then
		tArgs.sDeckNode = vDeck.getNodeName();
	end
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_HAND_DISCARDED, 
		tArgs,
		tEventTrace
	);
end

---Raises the onCardReturnedToDeck event
---@param vCard databasenode
---@param vDeck databasenode
---@param sIdentity string
---@param bFacedown boolean
---@param tEventTrace table
---@return table tEventTrace
function raiseOnCardReturnedToDeckEvent(vCard, vDeck, sIdentity, bFacedown, tEventTrace)
	local tArgs = { sIdentity = sIdentity, sCardNode = vCard.getNodeName(), sDeckNode = vDeck.getNodeName() }
	if bFacedown then
		tArgs.bFacedown = "true";
	end
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_PUT_BACK_IN_DECK,
		tArgs,
		tEventTrace
	);
end

---Raises the onHandReturnedToDeck event.
---@param sIdentity string Character identity (or 'gm') of the person discarding their hand
---@param vDeck databasenode optional. Deck node for which cards should be discarded
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnHandReturnedToDeckEvent(sIdentity, vDeck, tEventTrace)
	local tArgs = { sIdentity = sIdentity };
	if vDeck then
		tArgs.sDeckNode = vDeck.getNodeName();
	end
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_HAND_PUT_BACK_IN_DECK, 
		tArgs,
		tEventTrace
	);
end

---Raises the onGiveCard event
---@param vCard databasenode Card node for the card that's given, AFTER the move has taken place
---@param sGiverIdentity string Character identity (or 'gm') for the person giving the card
---@param sReceiverIdentity string Character identity (or 'gm') for the person receiving the card
---@param bFacedown boolean Facedown or not
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnGiveCardEvent(vCard, sGiverIdentity, sReceiverIdentity, bFacedown, tEventTrace)
	local tArgs = { sCardNode = vCard.getNodeName(), sGiver = sGiverIdentity, sReceiver = sReceiverIdentity };
	if bFacedown then
		tArgs.bFacedown = "true";
	end

	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_GIVEN, 
		tArgs,
		tEventTrace,
		true -- true because this event technically happens after addCardToHand, and by then the trace is already updated
	);
end

---Raises the onCardDeal event
---@param vCard databasenode Card node for the card that's dealt, AFTER the move has taken place
---@param sIdentity string Character identity (or 'gm') for the person receiving the card
---@param bFacedown boolean
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnDealCardEvent(vCard, sIdentity, bFacedown, tEventTrace)
	local tArgs = { sCardNode = vCard.getNodeName(), sReceiver = sIdentity }
	if bFacedown then
		tArgs.bFacedown = "true";
	end
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_DEALT, 
		tArgs,
		tEventTrace,
		true -- true because this event technically happens after addCardToHand, and by then the trace is already updated
	);
end

---Raises the onCardDealtFromDiscard event event.
---@param vCard databasenode Card that is added to hand, AFTER is is added to the hand
---@param sIdentity string Character identity (or 'gm') of the person whose hand the card is being added to
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnCardDealtFromDiscardEvent(vCard, sIdentity, bFacedown, tEventTrace)
	local tArgs = { sCardNode = vCard.getNodeName(), sIdentity = sIdentity, bFacedown = "false" };
	if bFacedown then
		tArgs.bFacedown = "true";
	end

	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_DEALT_FROM_DISCARD, 
		tArgs,
		tEventTrace,
		true -- True because this event technically happens after moveCard, and by then the trace is already updated
	);
end

---Raises the onCardFlipped event
---@param vCard databasenode
---@param sIdentity string Charater identity (or 'gm') of the person flipping the card
---@param nFacing number 1 = face up, 0 = face down
---@param tEventTrace table
---@return table tEventTrace
function raiseOnCardFlippedEvent(vCard, sIdentity, nFacing, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_FLIPPED,
		{ sCardNode = vCard.getNodeName(), sIdentity = sIdentity, nFacing = nFacing },
		tEventTrace
	);
end

---Raises the onPeekCard event
---@param vCard databasenode
---@param sIdentity string Character identity (or 'gm') of the person peeking the card
---@param tEventTrace table
---@return table tEventTrace
function raiseOnCardPeekEvent(vCard, sIdentity, tEventTrace)
	return raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_PEEK,
		{ sCardNode = vCard.getNodeName(), sIdentity = sIdentity },
		tEventTrace
	);
end

---Raises the onMultipleCardsDealt event
---@param vDeck databasenode Deck node for the deck the cards are dealt from
---@param nCardsDealt number Number of cards being dealt
---@param sIdentity string Character identity (or 'gm') for the person receiving the dealt cards
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnMultipleCardsDealtEvent(vDeck, nCardsDealt, sIdentity, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_MULTIPLE_CARDS_DEALT, 
		{ sDeckNode = vDeck.getNodeName(), nCardsDealt = nCardsDealt, sReceiver = sIdentity },
		tEventTrace
	);
end

---Raises the onDealCardsToActiveIdentities event
---@param vDeck databasenode Deck node for the deck the cards are dealt from
---@param nCardsDealt number Number of cards being dealt
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnDealCardsToActiveIdentitiesEvent(vDeck, nCardsDealt, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_GROUP_DEAL, 
		{ sDeckNode = vDeck.getNodeName(), nCardsDealt = nCardsDealt },
		tEventTrace
	);
end

---Raises the onCardAddedToStorage event
---@param vCard databasenode Card node that is added to storage, AFTER the move event
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnCardAddedToStorageEvent(vCard, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_ADDED_TO_STORAGE, 
		{ sCardNode = vCard.getNodeName() },
		tEventTrace
	);
end

---Raises the onDeckCreated event
---@param vDeck databasenode Deck node that was created
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnDeckCreatedEvent(vDeck, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_DECK_CREATED, 
		{ sDeckNode = vDeck.getNodeName() },
		tEventTrace
	);
end

---Raises the onDeckDeleted event
---@param vDeck databasenode Deck node that was created
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnDeckDeletedEvent(vDeck, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_DECK_DELETED, 
		{ sDeckNode = vDeck.getNodeName() },
		tEventTrace
	);
end

---Raises the onDeckSettingChanged event
---@param vDeck databasenode Deck node for which the settring was changed
---@param sSettingKey string Settings key that was changed
---@param sPreviousValue string Previous value
---@param sCurrentValue string Current value
---@param tEventTrace table. Event trace table
---@return table tEventTrace Event trace table
function raiseOnDeckSettingChangedEvent(vDeck, sSettingKey, sPreviousValue, sCurrentValue, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_DECK_SETTING_CHANGED, 
		{ sDeckNode = vDeck.getNodeName(), sSettingKey = sSettingKey, sPrev = sPreviousValue, sCur = sCurrentValue },
		tEventTrace
	);
end

-- Not used currently. Will be used if we add full cards on images support
function raiseOnCardAddedToImageEvent(tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_IMAGE_CARD_ADDED, 
		{  },
		tEventTrace
	);
end

-- Not used currently. Will be used if we add full cards on images support
function raiseOnCardDeletedFromImageEvent(tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_IMAGE_CARD_ADDED, 
		{  },
		tEventTrace
	);
end

-----------------------------------------------------
-- EVENT HANDLERS
-----------------------------------------------------
---Handles deleting cards that belong to decks that themselves are deleted
---@param tEventArgs table Event arguments table
---@param tEventTrace table Event trace table
function deleteCardsFromDecksThatAreDeleted(tEventArgs, tEventTrace)
	-- We can't get the actual deck here because by the time this event fires,
	-- the deck is gone. So we use tEventArgs.sDeckNode
	-- Go through all characters
	for k,v in pairs(DB.getChildren("charsheet")) do
		for _, card in pairs(DB.getChildren(v, CardsManager.PLAYER_HAND_PATH)) do
			if CardsManager.getDeckIdFromCard(card) == tEventArgs.sDeckNode then
				card.delete();
			end
		end
	end

	-- Go through the GM hand
	for _, card in pairs(DB.getChildren(CardsManager.GM_HAND_PATH)) do
		if CardsManager.getDeckIdFromCard(card) == tEventArgs.sDeckNode then
			card.delete();
		end
	end
end

-----------------------------------------------------
-- CARD DROP HANDLERS
-----------------------------------------------------
---Event for when a card is dropped in chat
---@param draginfo dragdata Dragdata info
---@return boolean bEndEvent If the return is true, the event is handled.
function onCardDroppedInChat(draginfo)
	local sClass,sRecord = draginfo.getShortcutData();
	-- Only handle card drops
	if sClass ~= "card" then
		return;
	end

	-- If the card is already in card storage, then don't do anything
	if CardStorage.doesCardComeFromStorage(sRecord) then
		return;	
	end

	local tEventTrace = {}; -- New up a trace, as this is guaranteed to be the first event

	-- We specifically don't want to copy cards to storage here, since the message
	-- handler will will copy it to chat. We only want to raise the event
	CardsManager.playCard(sRecord, DeckedOutUtilities.getFacedownHotkey(), DeckedOutUtilities.shouldPlayAndDiscard(sRecord), tEventTrace)
	return true;
end

---Event for when a card is dropped on a token (on an image)
---@param tokenCT string String prototype for the token the card was dropped on
---@param draginfo dragdata Dragdata info
---@return boolean bEndEvent If the return is true, the event is handled.
function onCardDroppedOnToken(tokenCT, draginfo)
	local nodeCT = CombatManager.getCTFromToken(tokenCT);
	if not nodeCT then
		return false;
	end

	return CardsManager.onDropCard(draginfo, nodeCT);
end

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

	local vCard = DeckedOutUtilities.validateCard(sRecord);
	local sCardBack = CardsManager.getCardBack(vCard);
	
	-- whether we place a card face down or face up is a bit tricky
	-- If the card was dragged from its source with the hotkey pressed and is thus face down
	-- then we always want to place face down
	-- If the card was dragged from its source face up, then we want to place the card
	-- respecting whether the facedown hotkey is currently pressed upon  dropping
	local sToken = draginfo.getTokenData();
	local bFacedown = sToken == sCardBack;

	if DeckedOutUtilities.getFacedownHotkey() then
		sToken = sCardBack;
		bFacedown = true;
	end

	if sToken then
		local token = cImageControl.addToken(sToken, x, y)
		TokenManager.autoTokenScale(token);

		CardsManager.playCard(sRecord, bFacedown, DeckedOutUtilities.shouldPlayAndDiscard(), {})

		return token ~= nil;
	end
end

---Event for when a card is dropped onto the hotkeybar
---@param dragdata dragdata Dragdata info
---@return boolean bEndEvent If the return is true, the event is handled.
function onCardDroppedOnHotkey(dragdata)
	local sClass,sRecord = dragdata.getShortcutData();
	-- Only handle card drops
	if sClass ~= "card" then
		return false;
	end
	local vCard = CardStorage.addCardToStorage(sRecord);
	dragdata.setDatabaseNode(vCard);
	dragdata.setShortcutData(sClass, vCard.getNodeName());
end

-----------------------------------------------------
-- HELPERS
-----------------------------------------------------
---Returns true if the provided event trace contains the given event key
---@param tEventTrace table Event trace table
---@param sEventName string Event key to search for
---@return boolean bIncludes Returns true if the trace contains the given event, otherwise false
function doesEventTraceContain(tEventTrace, sEventName)
	for _,v in ipairs(tEventTrace) do
		if v == sEventName then
			return true;
		end
	end
	return false;
end