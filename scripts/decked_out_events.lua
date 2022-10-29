DECKEDOUT_EVENT_CARD_PLAYED = "cardplayed";
DECKEDOUT_EVENT_CARD_DISCARDED = "carddiscarded";
DECKEDOUT_EVENT_CARD_GIVEN = "cardgiven";
DECKEDOUT_EVENT_CARD_DEALT = "carddealt";
DECKEDOUT_EVENT_CARD_ADDED_TO_STORAGE = "cardaddedtostorage";
DECKEDOUT_EVENT_CARD_MOVED = "cardmoved";
DECKEDOUT_EVENT_CARD_ADDED_TO_HAND = "cardaddedtohand";
DECKEDOUT_EVENT_MULTIPLE_CARDS_DEALT = "multiplecardsdealt";
DECKEDOUT_EVENT_GROUP_DEAL = "groupdeal";

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
	DeckedOutEvents.raiseOnDeckDeletedEvent(nodeDeck.getNodeName(), {})
end

function onDeckAdded(nodeDeck)
	DeckedOutEvents.raiseOnDeckCreatedEvent(nodeDeck.getNodeName(), {})
end

local _tEvents = {};
-----------------------------------------------------
-- EVENT REGISTRATION
-----------------------------------------------------
---@class eventData
---@field fCallback function The function that is called when the event is raised
---@field target string "host", "client", "immediate", or nil. Specifies where this callback will occur. Immediate will happen without an OOB message being sent.

---Registers an event. 
---@param sEventKey string
---@param tEventData eventData 
function registerEvent(sEventKey, tEventData)
	if not _tEvents[sEventKey] then
		_tEvents[sEventKey] = {};
	end

	table.insert(_tEvents[sEventKey], tEventData);
end

-- tArgs must be a table with only string values
-- tEventTrace must be a list of strings
-- Events are only raised if there are handlers for those events, but we still want to preserve the event trace
function raiseEvent(sEventKey, tArgs, tEventTrace, bDontAddTrace)
	if not tEventTrace then
		tEventTrace = {};
	end
	if not bDontAddTrace then
		table.insert(tEventTrace, sEventKey);
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

-- This is kind of a hacky way to get around some order of operations problems in the call stack
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
function raiseOnCardPlayedEvent(sCardNode, bFacedown, bDiscard, tEventTrace)
	local tArgs = { sCardNode = sCardNode };
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

-- vCard and vDestination are both card nodes, the former where it came from, and the latter where it is moved to
function raiseOnCardMovedEvent(sCardNode, sOldCardNode, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_MOVED, 
		{ sCardNode = sCardNode, sOldCardNode = sOldCardNode },
		tEventTrace
	);
end

-- vCard: card added to hand
-- sIdentity: identity of the user whose hand the card was added to. Either a user identity node name or "gm"
function raiseOnCardAddedToHandEvent(sCardNode, sIdentity, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_ADDED_TO_HAND, 
		{ sCardNode = sCardNode, sIdentity = sIdentity },
		tEventTrace,
		true -- True because this event technically happens after moveCard, and by then the trace is already updated
	);
end

-- vCard: card discarded
-- sSender: identity (or 'gm') of the character that is doing the discarding
-- bFacedown: optional. If present, specifes that cards were discarded sight unseen
function raiseOnDiscardFromHandEvent(sCardNode, sSender, bFacedown, tEventTrace)
	local tArgs = { sCardNode = sCardNode, sSender = sSender };
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

-- sIdentity: identity of the user whose hand to discard
-- sDeckNode: optional. If present, specifies that only cards from this deck were discarded
function raiseOnHandDiscardedEvent(sIdentity, sDeckNode, tEventTrace)
	local tArgs = { sIdentity = sIdentity };
	if (sDeckNode or "") ~= "" then
		tArgs.sDeckNode = sDeckNode;
	end
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_HAND_DISCARDED, 
		tArgs,
		tEventTrace
	);
end

-- sIdentity: identity of the user whose hand returned to deck
-- sDeckNode: optional. if present, this specificies that only cards from this deck node were returned to the hand, not all.
function raiseOnHandReturnedToDeckEvent(sIdentity, sDeckNode, tEventTrace)
	local tArgs = { sIdentity = sIdentity };
	if (sDeckNode or "") ~= "" then
		tArgs.sDeckNode = sDeckNode;
	end
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_HAND_PUT_BACK_IN_DECK, 
		tArgs,
		tEventTrace
	);
end

function raiseOnGiveCardEvent(sCardNode, sGiverIdentity, sReceiverIdentity, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_GIVEN, 
		{ sCardNode = sCardNode, sGiver = sGiverIdentity, sReceiver = sReceiverIdentity },
		tEventTrace,
		true -- true because this event technically happens after addCardToHand, and by then the trace is already updated
	);
end

function raiseOnDealCardEvent(sCardNode, sIdentity, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_DEALT, 
		{ sCardNode = sCardNode, sReceiver = sIdentity },
		tEventTrace,
		true -- true because this event technically happens after addCardToHand, and by then the trace is already updated
	);
end

function raiseOnMultipleCardsDealtEvent(sDeckNode, nCardsDealt, sIdentity, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_MULTIPLE_CARDS_DEALT, 
		{ sDeckNode = sDeckNode, nCardsDealt = nCardsDealt, sReceiver = sIdentity },
		tEventTrace
	);
end

function raiseOnDealCardsToActiveIdentitiesEvent(sDeckNode, nCardsDealt, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_GROUP_DEAL, 
		{ sDeckNode = sDeckNode, nCardsDealt = nCardsDealt },
		tEventTrace
	);
end

function raiseOnCardAddedToStorageEvent(sCardNode, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_CARD_ADDED_TO_STORAGE, 
		{ sCardNode = sCardNode },
		tEventTrace
	);
end

function raiseOnDeckCreatedEvent(sDeckNode, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_DECK_CREATED, 
		{ sDeckNode = sDeckNode },
		tEventTrace
	);
end

function raiseOnDeckDeletedEvent(sDeckNode, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_DECK_DELETED, 
		{ sDeckNode = sDeckNode },
		tEventTrace
	);
end

function raiseOnDeckSettingChangedEvent(sDeckNode, sSettingKey, sPreviousValue, sCurrentValue, tEventTrace)
	return DeckedOutEvents.raiseEvent(
		DeckedOutEvents.DECKEDOUT_EVENT_DECK_SETTING_CHANGED, 
		{ sDeckNode = sDeckNode, sSettingKey = sSettingKey, sPrev = sPreviousValue, sCur = sCurrentValue },
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
-- This handles deleting cards that belong to decks that themselves are deleted
function deleteCardsFromDecksThatAreDeleted(tEventArgs, tEventTrace)
	-- We can't get the actual deck here because by the time this event fires,
	-- the deck is gone
	-- Go through all characters
	for k,v in pairs(DB.getChildren("charsheet")) do
		for _, card in pairs(DB.getChildren(v, CardManager.PLAYER_HAND_PATH)) do
			if CardManager.getDeckIdFromCard(card) == tEventArgs.sDeckNode then
				card.delete();
			end
		end
	end

	-- Go through the GM hand
	for _, card in pairs(DB.getChildren(CardManager.GM_HAND_PATH)) do
		if CardManager.getDeckIdFromCard(card) == tEventArgs.sDeckNode then
			card.delete();
		end
	end
end

-----------------------------------------------------
-- CARD DROP HANDLERS
-----------------------------------------------------
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
	CardManager.playCard(sRecord, DeckedOutUtilities.getFacedownHotkey(), tEventTrace)
	return true;
end

function onCardDroppedOnToken(tokenCT, draginfo)
	local nodeCT = CombatManager.getCTFromToken(tokenCT);
	if not nodeCT then
		return false;
	end

	return CardManager.onDropCard(draginfo, nodeCT);
end

function onCardDroppedOnImage(cImageControl, x, y, draginfo)
	local sClass,sRecord = draginfo.getShortcutData();
	-- Only handle card drops
	if sClass ~= "card" then
		return false;
	end

	local vCard = DeckedOutUtilities.validateCard(sRecord);
	local sCardBack = CardManager.getCardBack(vCard);
	
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

		CardManager.playCard(sRecord, bFacedown, {})

		return token ~= nil;
	end
end

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
function doesEventTraceContain(tEventTrace, sEventName)
	for _,v in ipairs(tEventTrace) do
		if v == sEventName then
			return true;
		end
	end
	return false;
end