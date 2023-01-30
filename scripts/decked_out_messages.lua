OOB_MSGTYPE_DECKEDOUT_STANDARD = "standard_message_handler";

-- All of these message events need to start from the host because the host needs to add any cards to storage before sending out another OOB
-- That second OOB message is the one that actually prints to chat
function onInit()
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_PLAYED, { fCallback = printCardPlayedMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_HAND_PLAY_RANDOM, { fCallback = printRandomCardPlayedMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_DISCARDED, { fCallback = printCardDiscardedMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_HAND_DISCARD_RANDOM, { fCallback = printRandomCardDiscardedMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_GIVEN, { fCallback = printCardGivenMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_DEALT, { fCallback = printCardDealtMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_DEALT_FROM_DISCARD, { fCallback = printCardDealtFromDiscardMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_HAND_DISCARDED, { fCallback = printHandDiscardedMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_MULTIPLE_CARDS_DEALT, { fCallback = printMultipleCardsDealtMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_GROUP_DEAL, { fCallback = printGroupDealMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_PUT_BACK_IN_DECK, { fCallback = printCardPutBack, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_HAND_PUT_BACK_IN_DECK, { fCallback = printHandPutBack, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_FLIPPED, { fCallback = printCardFlippedMessage, sTarget = "host" });
	DeckedOutEvents.registerEvent(DeckedOutEvents.DECKEDOUT_EVENT_CARD_PEEK, { fCallback = printPeekCardMessage, sTarget = "host" });

	-- These oob messages are needed because cards are printed to chat. the GM must copy referenced cards to card storage
	-- Before sending the message to chat. Clients can't copy to storage.
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_DECKEDOUT_STANDARD, DeckedOutMessages.standardMessageHandler);
end

function standardMessageHandler(msgOOB)
	-- Only the GM should be handling this event
	if not Session.IsHost then
		return;
	end

	-- Before we do anything else, we need to copy the card link
	-- into card storage
	local newCard = CardStorage.addCardToStorage(msgOOB.card_link);
	msgOOB.card_link = newCard.getNodeName();

	sendMessageToGm(msgOOB);
	sendMessageToClients(msgOOB);
end

-----------------------------------------------------
-- PLAYING CARDS
-----------------------------------------------------
function printCardPlayedMessage(tEventArgs, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	-- If this is called as part of the play random event, don't print a message
	if DeckedOutEvents.doesEventTraceContain(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_HAND_PLAY_RANDOM) then
		return;
	end

	local bFacedown = tEventArgs.bFacedown == "true";
	local sCardSource = CardsManager.getCardSource(vCard);
	if sCardSource == "storage" then return end

	-- In this case, everything is public so the two messages can be the same
	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	msg.sender = sCardSource;
	msg.action = "play";
	msg.facedown = tEventArgs.bFacedown;
	
	local bDiscard = tEventArgs.bDiscard == "true";
	local sTextRes = "";
	if bFacedown then
		if bDiscard then
			msg.text = Interface.getString("chat_msg_card_played_discarded_facedown");
		else
			msg.text = Interface.getString("chat_msg_card_played_facedown");
		end
		msg.icon = "play_facedown";
	else
		if bDiscard then
			msg.text = Interface.getString("chat_msg_card_played_discarded_faceup");
		else
			msg.text = Interface.getString("chat_msg_card_played_faceup");
		end
		msg.icon = "play_faceup";
	end

	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]");
	msg.card_link = vCard.getNodeName();

	Comm.deliverOOBMessage(msg, "");
end

function printRandomCardPlayedMessage(tEventArgs, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	local bFacedown = tEventArgs.bFacedown == "true";
	local sCardSource = CardsManager.getCardSource(vCard);
	if sCardSource == "storage" then return end

	-- In this case, everything is public so the two messages can be the same
	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	msg.sender = sCardSource;
	msg.action = "play";
	msg.facedown = tEventArgs.bFacedown;
	
	local bDiscard = tEventArgs.bDiscard == "true";
	local sTextRes = "";
	if bFacedown then
		if bDiscard then
			msg.text = Interface.getString("chat_msg_card_randomly_played_discarded_facedown");
		else
			msg.text = Interface.getString("chat_msg_card_randomly_played_facedown");
		end
		msg.icon = "play_facedown";
	else
		if bDiscard then
			msg.text = Interface.getString("chat_msg_card_randomly_played_discarded_faceup");
		else
			msg.text = Interface.getString("chat_msg_card_randomly_played_faceup");
		end
		msg.icon = "play_faceup";
	end

	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]");
	msg.card_link = vCard.getNodeName();

	Comm.deliverOOBMessage(msg, "");
end

-----------------------------------------------------
-- DISCARDING CARDS
-----------------------------------------------------
function printCardDiscardedMessage(tEventArgs, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(tEventArgs.sSender) then return end
	vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	-- If the event trace already contains the discard hand event, then we don't want to print out any messages, so we bail
	if DeckedOutEvents.doesEventTraceContain(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_HAND_DISCARDED) then
		return;
	end
	-- Check if trace contains a played action, if so, don't print the message
	if DeckedOutEvents.doesEventTraceContain(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_PLAYED) then
		return;
	end
	-- don't show action as part of the discard random event
	if DeckedOutEvents.doesEventTraceContain(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_HAND_DISCARD_RANDOM) then
		return;
	end

	local bFacedown = tEventArgs.bFacedown == "true";

	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	msg.sender = tEventArgs.sSender;
	msg.action = "discard";
	msg.facedown = tEventArgs.bFacedown;
	msg.icon = "discard_card";

	local sTextRes = "";
	if bFacedown then
		msg.text = Interface.getString("chat_msg_card_discarded_facedown");
	else
		msg.text = Interface.getString("chat_msg_card_discarded_faceup");
	end

	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]");
	msg.card_link = vCard.getNodeName();

	Comm.deliverOOBMessage(msg, "");
end

function printRandomCardDiscardedMessage(tEventArgs, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(tEventArgs.sSender) then return end
	vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	local bFacedown = tEventArgs.bFacedown == "true";

	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	msg.sender = tEventArgs.sSender;
	msg.action = "discard";
	msg.facedown = tEventArgs.bFacedown;
	msg.icon = "discard_random";

	local sTextRes = "";
	if bFacedown then
		msg.text = Interface.getString("chat_msg_card_discarded_facedown");
	else
		msg.text = Interface.getString("chat_msg_card_discarded_faceup");
	end

	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]");
	msg.card_link = vCard.getNodeName();

	Comm.deliverOOBMessage(msg, "");
end

-- This is configured to run only on the host
-- No cards are posted in chat so no need for an OOB message
function printHandDiscardedMessage(tEventArgs, tEventTrace)
	if not DeckedOutUtilities.validateParameter(tEventArgs.sIdentity, "sIdentity") then
		return;
	end

	local msg = {};
	msg.sender = tEventArgs.sIdentity;
	msg.text = Interface.getString("chat_msg_discarded_hand");
	msg.text = string.format(msg.text, "[SENDER]", "[PRONOUN]")
	msg.icon = "discard_hand";

	sendMessageToGm(msg);
	sendMessageToClients(msg);
end

function printCardPutBack(tEventArgs, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(tEventArgs.sIdentity) then return end;
	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	local vDeck = DeckedOutUtilities.validateDeck(tEventArgs.sDeckNode);

	local sDeckName = "the deck";
	if vDeck then
		sDeckName = DeckManager.getDeckName(vDeck);
	end

	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	msg.sender = tEventArgs.sIdentity;
	msg.action = "reshuffle";
	msg.facedown = tEventArgs.bFacedown;
	msg.icon = "reshuffle_card";

	local sTextRes = "";
	msg.text = Interface.getString("chat_msg_card_put_back_in_deck");
	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]");
	msg.card_link = vCard.getNodeName();

	Comm.deliverOOBMessage(msg, "");
end

function printHandPutBack(tEventArgs, tEventTrace)
	if not DeckedOutUtilities.validateIdentity(tEventArgs.sIdentity) then return end;
	local vDeck = DeckedOutUtilities.validateDeck(tEventArgs.sDeckNode);

	local sDeckName = "the deck";
	if vDeck then
		sDeckName = DeckManager.getDeckName(vDeck);
	end

	local msg = {};
	msg.sender = tEventArgs.sIdentity;
	msg.text = Interface.getString("chat_msg_hand_put_back_in_deck");
	msg.text = string.format(msg.text, "[SENDER]", "[PRONOUN]", sDeckName)
	msg.icon = "reshuffle_hand";

	sendMessageToGm(msg);
	sendMessageToClients(msg);
end

-----------------------------------------------------
-- GIVING AND DEALING CARDS TO ONE PERSON
-----------------------------------------------------
function printCardGivenMessage(tEventArgs, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	local bFacedown = tEventArgs.bFacedown == "true";
	local sCardSource = CardsManager.getCardSource(vCard);
	if (not sCardSource) or sCardSource == "storage" then
		return;
	end

	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	msg.sender = tEventArgs.sGiver;
	msg.receiver = tEventArgs.sReceiver;
	msg.card_link = vCard.getNodeName();
	msg.action = "give";
	msg.facedown = tEventArgs.bFacedown;
	msg.icon = "give_card"

	if bFacedown then
		msg.text = Interface.getString("chat_msg_give_card_facedown");
	else
		msg.text = Interface.getString("chat_msg_give_card_faceup");
	end

	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]", "[PRONOUN]");

	Comm.deliverOOBMessage(msg, "");
end

function printCardDealtMessage(tEventArgs, tEventTrace)
	-- If the event trace already contains the deal multiple cards event, then we don't want to print out any messages, so we bail
	if DeckedOutEvents.doesEventTraceContain(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_MULTIPLE_CARDS_DEALT) then
		return;
	end

	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	local sCardSource = CardsManager.getCardSource(vCard);
	if (not sCardSource) or sCardSource == "storage" then
		return;
	end

	local bFacedown = tEventArgs.bFacedown == "true";

	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	-- The GM should always be the card source here. 
	-- If we use value returned from getCardSource, 
	-- it will always say the PC since we dealt them the card prior to this event
	msg.sender = "gm"; 
	msg.receiver = tEventArgs.sReceiver;
	msg.card_link = vCard.getNodeName();
	msg.action = "deal";
	msg.facedown = tEventArgs.bFacedown;
	if bFacedown then
		msg.text = Interface.getString("chat_msg_deal_card_facedown");
	else
		msg.text = Interface.getString("chat_msg_deal_card");
	end
	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]", "[PRONOUN]");
	msg.icon = "deal";

	Comm.deliverOOBMessage(msg, "");
end

function printCardDealtFromDiscardMessage(tEventArgs, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	local sCardSource = CardsManager.getCardSource(vCard);
	if (not sCardSource) or sCardSource == "storage" then
		return;
	end

	local bFacedown = tEventArgs.bFacedown == "true";

	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	-- The GM should always be the card source here. 
	-- If we use value returned from getCardSource, 
	-- it will always say the PC since we dealt them the card prior to this event
	msg.sender = tEventArgs.sIdentity;
	msg.card_link = vCard.getNodeName();
	msg.action = "deal";
	msg.facedown = tEventArgs.bFacedown;
	if bFacedown then
		msg.text = Interface.getString("chat_msg_deal_card_from_discard_facedown");
	else
		msg.text = Interface.getString("chat_msg_deal_card_from_discard");
	end
	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]");
	msg.icon = "deal";

	Comm.deliverOOBMessage(msg, "");
end

function printMultipleCardsDealtMessage(tEventArgs, tEventTrace)
	-- If the event trace already contains the group deal cards event, then we don't want to print out any messages, so we bail
	if DeckedOutEvents.doesEventTraceContain(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_GROUP_DEAL) then
		return;
	end

	local nCardsDealt = tEventArgs.nCardsDealt;
	local sCardPlural = "card";
	if (tonumber(nCardsDealt) or 0) ~= 1 then
		sCardPlural = "cards";
	end

	local msg = {};
	-- The GM should always be the card source here. 
	-- If we use value returned from getCardSource, 
	-- it will always say the PC since we dealt them the card prior to this event
	msg.sender = "gm"; 
	msg.receiver = tEventArgs.sReceiver;
	msg.text = Interface.getString("chat_msg_deal_multiple_cards");
	msg.text = string.format(msg.text, "[SENDER]", nCardsDealt, sCardPlural, "[PRONOUN]");
	msg.icon = "multideal";

	sendMessageToGm(msg);
	sendMessageToClients(msg);
end
-----------------------------------------------------
-- FLIPPING AND PEEKING
-----------------------------------------------------

function printCardFlippedMessage(tEventArgs, tEventTrace)
	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end

	local sFacing = "face up";
	if tonumber(tEventArgs.nFacing) == 0 then
		sFacing = "face down";
	end
	
	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	msg.card_link = vCard.getNodeName();
	msg.action = "flip";
	msg.sender = tEventArgs.sIdentity;
	msg.text = Interface.getString("chat_msg_card_flipped");
	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]", sFacing);
	msg.icon = "flip";

	Comm.deliverOOBMessage(msg, "");
end

function printPeekCardMessage(tEventArgs, tEventTrace)
	-- Check if we should post a message when a GM performs the peek action
	if tEventArgs.sIdentity == "gm" and not DeckedOutUtilities.showGmPeekMessage() then
		return
	end

	local vCard = DeckedOutUtilities.validateCard(tEventArgs.sCardNode);
	if not vCard then return end
	
	local msg = {};
	msg.type = DeckedOutMessages.OOB_MSGTYPE_DECKEDOUT_STANDARD;
	msg.card_link = vCard.getNodeName();
	msg.action = "peek";
	msg.sender = tEventArgs.sIdentity;
	msg.text = Interface.getString("chat_msg_peek");
	msg.text = string.format(msg.text, "[SENDER]", "[CARDNAME]");
	msg.icon = "peek";

	Comm.deliverOOBMessage(msg, "");
end

-----------------------------------------------------
-- DEALING CARDS TO GROUP
-----------------------------------------------------
function printGroupDealMessage(tEventArgs, tEventTrace)
	local nCardsDealt = tEventArgs.nCardsDealt;
	local sCardPlural = "card";
	if (tonumber(nCardsDealt) or 0) ~= 1 then
		sCardPlural = "cards";
	end

	local msg = {};
	-- The GM should always be the card source here
	msg.sender = "gm"; 
	msg.text = Interface.getString("chat_msg_group_deal");
	msg.text = string.format(msg.text, "[SENDER]", nCardsDealt, sCardPlural);
	msg.icon = "deal_multiperson";

	sendMessageToGm(msg);
	sendMessageToClients(msg);
end

-----------------------------------------------------
-- NOTIFICATIONS
-----------------------------------------------------
function printNotEnoughCardsInDeckMessage(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local msg = {};

	local sDeckName = DeckManager.getDeckName(vDeck);
	msg.text = string.format(Interface.getString("chat_msg_not_enough_cards_in_deck"), sDeckName);
	msg.font = "systemfont";

	Comm.addChatMessage(msg)
end

-----------------------------------------------------
-- HELPERS
-----------------------------------------------------
function getUserDisplayNameForCard(vCard)
	if Session.IsHost then
		return "The GM";
	else
		return ActorManager.getDisplayName(CardsManager.getActorHoldingCard(vCard));
	end
end

function resolveIdentityName(sIdentity, sMessageIdentity)
	if not sIdentity then
		return nil;
	end
	if sIdentity == sMessageIdentity then
		return "you";
	end
	if sIdentity == "gm" then
		return "the GM";
	else
		return ActorManager.getDisplayName(
			ActorManager.resolveActor(
				DB.findNode(
					DB.getPath("charsheet", sIdentity))));
	end
end

function resolvePronouns(sSender, sReceiver, sMessageId, sDefault)
	if (sReceiver or "") == "" then
		-- If there is no receiver, then we only use 'your', 'their', and 'name'
		if sSender == sMessageId then
			return "your";
		elseif (sDefault or "") == "" then
			return "their";
		end
	else
		-- If there is a receiver, then we use 'yourself, 'themselves', and 'name
		if sSender == sReceiver and sSender == sMessageId then
			return "yourself";
		end
		if sReceiver == sMessageId then
			return "you";
		elseif sSender == sReceiver then
			return "themselves";
		end
	end
	return sDefault;
end

-- Returns true if the card is visible, and false if not visible
function resolveCardVisibility(msg, sSenderName, sReceiverName, sMessageId)
	local sSetting = nil;

	local vDeck = CardsManager.getDeckNodeFromCard(msg.card_link);
	if not vDeck then return true end -- Would be weird if this happened

	-- We resolve facedown cards first because by default they're never visible
	-- So it's facedown, we don't have to look any futher
	local bGmSeesFacedown = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_GM_SEE_FACEDOWN_CARDS) == "yes";
	if msg.facedown == "true" and msg.action ~= "deal" then
		-- If this is the deal action, then we don't want to worry about the facedown status.
		-- We let the logic below this control who can see deals
		-- This is so if only the player being dealt shoudl see the message, we don't have to worry about whether the GM
		-- Can see facedown cards. They just don't ever see the cards dealt
		return (sMessageId == "gm" and bGmSeesFacedown) or sSenderName == "you";
	end

	if msg.action == "deal" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_DEAL_VISIBILITY);
	elseif msg.action == "play" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_PLAY_VISIBILITY);
	elseif msg.action == "give" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_GIVE_VISIBILITY);
	elseif msg.action == "discard" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_DISCARD_VISIBILITY);
	elseif msg.action == "flip" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_FLIP_VISIBILITY);
	elseif msg.action == "peek" then
		sSetting = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_PEEK_VISIBILITY);
	end

	-- If no action is present, then return false. i.e Card is not hidden
	if not sSetting then
		return true;
	end

	local bGmSeesCard = (not msg.facedown) or (msg.facedown and bGmSeesFacedown)

	-- If only the person giving/receiving a card should see the card
	-- Then we only return true when the sender is 'you'
	if sSetting == "actor" then
		-- Dealing cards is the one edge case, because the GM is always the sender
		if msg.action == "deal" then
			return sReceiverName == "you";
		end
		return sSenderName == "you" or sReceiverName == "you";
	elseif sSetting == "gmandactor" then
		return (sMessageId == "gm" and bGmSeesCard) or sSenderName == "you" or sReceiverName == "you";
	elseif sSetting == "gm" then
		return sMessageId == "gm" and bGmSeesCard;
	elseif sSetting == "none" then
		return false;
	end

	-- If we get here and sSetting is not everyone, then something went wrong
	if sSetting ~= "everyone" then
		Debug.console("ERROR: Deck setting for action '" .. msg.action .. "' was set to " .. sSetting .. " when 'everyone' was expected");
	end
	return sSetting == "everyone";
end

function formatChatMessage(msgOOB, sMessageId)
	local sText = msgOOB.text;
	local sSenderName = resolveIdentityName(msgOOB.sender, sMessageId);
	local sReceiverName = resolveIdentityName(msgOOB.receiver, sMessageId);
	local bShowCard = false

	local sPronoun = resolvePronouns(msgOOB.sender, msgOOB.receiver, sMessageId, sReceiverName);

	local sCardName = nil;
	if msgOOB.card_link then
		sCardName = CardsManager.getCardName(msgOOB.card_link);
		bShowCard = resolveCardVisibility(msgOOB, sSenderName, sReceiverName, sMessageId)
		
		if not bShowCard then
			sCardName = "a card";
		end
	end
	
	if sSenderName then
		sText = sText:gsub("%[SENDER%]", sSenderName);
	end
	if sReceiverName then
		sText = sText:gsub("%[RECEIVER%]", sReceiverName);
	end
	if sCardName then
		sText = sText:gsub("%[CARDNAME%]", sCardName);
	end
	if sPronoun then
		sText = sText:gsub("%[PRONOUN%]", sPronoun)
	end

	-- Capitalize the first letter of the text
	sText = (sText:gsub("^%l", string.upper))

	return sText, bShowCard;
end


function buildCardMessage(msgOOB, sRecipientIdentity)
	local msg = {};

	msg.icon = {};
	if msgOOB.sender == "gm" then
		table.insert(msg.icon, "portrait_gm_token");
	else
		local nodeActor = DB.findNode(DB.getPath("charsheet", msgOOB.sender));
		if nodeActor then
			table.insert(msg.icon, "portrait_" .. nodeActor.getName() .. "_chat");
		end
	end

	if msgOOB.icon then
		table.insert(msg.icon, msgOOB.icon);
	end

	local sText, bShowCard = formatChatMessage(msgOOB, sRecipientIdentity);
	if bShowCard and msgOOB.card_link then
		msg.shortcuts = {}
		table.insert(msg.shortcuts, { description = sText, class = "card", recordname = msgOOB.card_link });
	end

	msg.text = sText;
	msg.font = "systemfont";

	return msg;
end

function sendMessageToGm(msgOOB)
	local msg = buildCardMessage(msgOOB, "gm");
	Comm.deliverChatMessage(msg, "");
end

function sendMessageToClients(msgOOB)
	local aUsers = User.getActiveUsers();
	for k,user in ipairs(aUsers) do
		-- This could get weird if for some reason a player has 2 identities
		-- and they send a message with one but receive it on the other
		-- I can't imagine how that would happen, but it would be weird.
		local sCurrentId = User.getCurrentIdentity(user);
		local msg = buildCardMessage(msgOOB, sCurrentId);
		Comm.deliverChatMessage(msg, user)
	end
end