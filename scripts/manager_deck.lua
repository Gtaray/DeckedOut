DECK_CARDS_PATH = "cards";
DECK_DISCARD_PATH = "discard";
DECK_SETTINGS_PATH = "settings";

function onInit()
	DB.addHandler("charsheet.*", "onDelete", onCharacterDeleted);
end

function onCharacterDeleted(node)
	local handnode = node.getChild(CardManager.PLAYER_HAND_PATH);
	if not handnode then
		return
	end

	for k,card in pairs(handnode.getChildren()) do
		local deck = CardManager.getDeckNodeFromCard(card);
		if deck then
			CardManager.moveCard(card, DeckManager.getDiscardNode(deck), {});
		end
	end
end

------------------------------------------
-- EVENT FUNCTIONS
------------------------------------------

---Deals a card to an identity. Raises the onDealCard event
---@param vDeck databasenode|string Deck from which the card is dealt
---@param sIdentity string Character identity (or 'gm') that's receiving the card
---@param bFacedown boolean
---@param tEventTrace table Event trace table
---@return databasenode card The card that's dealt
function dealCard(vDeck, sIdentity, bFacedown, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end
	
	local aCards = DeckManager.getRandomCardsInDeck(vDeck, 1);

	bFacedown = bFacedown or DeckManager.dealFacedownByDefault(vDeck);

	if aCards and aCards[1] then
		-- We place a trace event above the addCardToHand call since that call generates more events
		-- We can't call the raise event before addCardToHand, because the card isn't in the hand, yet
		-- and sCardNode would be nil by the time a handler got to it otherwise (as it was moved from the deck)
		-- This makes sure that the trace stack is preserved, while still having the event fire second
		tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_DEALT);
		local card = CardManager.addCardToHand(aCards[1], sIdentity, bFacedown, tEventTrace);
		DeckedOutEvents.raiseOnDealCardEvent(card, sIdentity, bFacedown, tEventTrace);
		return card;
	end
end

---Deals multiple cards to one person. Raises the onMultipleCardsDealt event
---@param vDeck databasenode|string Deck from which the cards are dealt
---@param sIdentity string Character identity (or 'gm') that's receiving the card
---@param nCardAmount number Number of cards to deal
---@param tEventTrace table Event trace table
function dealCards(vDeck, sIdentity, nCardAmount, bFacedown, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end

	-- No idea why this would happen, but if it does, don't do anything
	if nCardAmount < 1 then
		return;
	end
	
	-- Raise the event first so that tEventTrace is updated and we don't get messages
	-- in chat for every card dealt
	tEventTrace = DeckedOutEvents.raiseOnMultipleCardsDealtEvent(vDeck, nCardAmount, sIdentity, tEventTrace)

	for i = 1, nCardAmount, 1 do
		DeckManager.dealCard(vDeck, sIdentity, false, tEventTrace);
	end
end

---Deals a card to all active identities. Raises the onGroupDeal event
---@param vDeck databasenode|string Deck from which the cards are dealt
---@param nCardAmount number Number of cards to deal
---@param tEventTrace table Event trace table
function dealCardsToActiveIdentities(vDeck, nCardAmount, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	-- No idea why this would happen, but if it does, don't do anything
	if nCardAmount < 1 then
		return;
	end

	tEventTrace = DeckedOutEvents.raiseOnDealCardsToActiveIdentitiesEvent(vDeck, nCardAmount, tEventTrace);

	for _,user in ipairs(User.getAllActiveIdentities()) do
		DeckManager.dealCards(vDeck, user, nCardAmount, tEventTrace);
	end
end

---Sets a deck setting. Raises the onDeckSettingChanged event
---@param vDeck databasenode|string Deck for which the setting is changed
---@param sKey string Setting key to chnage
---@param sValue string Value to change the setting to
---@param nCardAmount number Number of cards to deal
function setDeckSetting(vDeck, sKey, sValue, tEventTrace)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	if not DeckedOutUtilities.validateParameter(sValue, "sValue") then
		return
	end

	local settings = DeckManager.getDeckSettingsNode(vDeck);
	settings = DeckedOutUtilities.validateNode(settings, "deck.settings");
	if not settings then return end

	local node = DB.getChild(settings, sKey);
	node = DeckedOutUtilities.validateNode(node, "settingNode");
	if not node then return end

	local tEventTrace = DeckedOutEvents.raiseOnDeckSettingChangedEvent(
		vDeck, 
		sKey, 
		node.getValue(),
		sValue,
		tEventTrace);

		node.setValue(sValue);
end


------------------------------------------
-- DECK MANAGEMENT
------------------------------------------

---This function gets a card, without actually removing it from the deck
---@param vDeck databasenode|string Deck from which to draw a card
---@return databasenode card The databasenode for the card drawn from the deck
function drawCard(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local aCards = DeckManager.getRandomCardsInDeck(vDeck, 1);
	return aCards[1];
end

---Adds a card back to its orignial deck
---@param vCard databasenode|string Card that's being returned to its deck
---@return databasenode card The card node after it has been moved
function addCardToDeck(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vDeck then return end

	local vDeck = DeckedOutUtilities.validateDeck(CardManager.getDeckIdFromCard(vCard));
	if not vDeck then return end

	return CardManager.moveCard(vCard, DeckManager.getCardsNode(vDeck));
end

------------------------------------------
-- DISCARD PILE MANAGEMENT
------------------------------------------

---Moves the discard pile for a deck back into the deck
---@param vDeck databasenode|string The deck whose discard pile is put back into the deck
function moveDiscardPileIntoDeck(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local cardsNode = DeckManager.getCardsNode(vDeck);
	for k,cardNode in pairs(DeckManager.getDiscardNode(vDeck).getChildren()) do
		CardManager.moveCard(cardNode, cardsNode);
	end
end

------------------------------------------
-- DECK STATE
------------------------------------------

---Gets the node that contains the cards in the deck
---@param vDeck databasenode|string
---@return databasenode cardsNode
function getCardsNode(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.createChild(vDeck, DeckManager.DECK_CARDS_PATH);
end

---Gets the discard databasenode for the given deck
---@param vDeck databasenode|string
---@return databasenode discardNode
function getDiscardNode(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.createChild(vDeck, DeckManager.DECK_DISCARD_PATH);
	
end

---Gets the number of cards in a deck
---@param vDeck databasenode|string
---@return number cardCount
function getNumberOfCardsInDeck(vDeck) 
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local cards = DeckManager.getCardsNode(vDeck);
	if not cards then
		return;
	end

	return cards.getChildCount();
end

---Gets the number of cards in a deck's discard pile
---@param vDeck databasenode|string
---@return number cardCount
function getNumberOfCardsInDiscardPile(vDeck) 
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local discard = DeckManager.getDiscardNode(vDeck);
	if not discard then
		return;
	end

	return discard.getChildCount();
end

---Gets a number of random cards in a deck, without removing them
---@param vDeck databasenode|string
---@param nNumberOfCards number
---@return table cards An integer indexed table of card nodes randomly sampled from the deck.
function getRandomCardsInDeck(vDeck, nNumberOfCards)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local aCards = {};
	for k,v in pairs(DeckManager.getCardsNode(vDeck).getChildren()) do
		table.insert(aCards, v);
	end

	if #aCards < nNumberOfCards then
		DeckedOutMessages.printNotEnoughCardsInDeckMessage(vDeck);
		return nil;
	end

	local aResults = {};
	for i = 1, nNumberOfCards, 1 do
		local nEntry = math.random(1, #aCards);
		table.insert(aResults, table.remove(aCards, nEntry));
	end

	return aResults;
end

---Gets the token prototype representing the back of a deck
---@param vDeck databasenode|string
---@return string tokenPrototype
function getDecksCardBack(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.getValue(vDeck, "back", "");
end

---Gets the full database ID for the deck
---@param vDeck databasenode|string
---@return string deckNodeName
function getDeckId(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return vDeck.getNodeName();
end

---Gets the name of the deck
---@param vDeck databasenode|string
---@return string deckName
function getDeckName(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.getValue(vDeck, "name", "");
end

------------------------------------------
-- DECK SETTINGS
------------------------------------------
-- These setting values need to match the settings.* source nodes for all settings
-- Are cards dealt from this deck dealt faceup or facedown by default
-- Default: faceup
DECK_SETTING_DEFAULT_DEAL_FACING = "defaultdealfacing"
-- Who can see cards that are being dealt: player, player and GM, everyone
-- Default: player and GM
DECK_SETTING_DEAL_VISIBILITY = "dealvisibility";
-- Who can see cards that are being played: player, player and GM, everyone
-- Default: player and GM
DECK_SETTING_PLAY_VISIBILITY = "playvisibility";
-- Who can see cards that are being discarded: discarder, discarder and GM, everyone
-- Default: discarder and GM
DECK_SETTING_DISCARD_VISIBILITY = "discardvisibility";
-- Who can see cards that are being given: giver and receiver, giver and receiver and gm, everyone
-- Default: giver and receiver and gm
DECK_SETTING_GIVE_VISIBILITY = "givevisibility";
-- Who can see cards that are flipped: flipper, flipper and gm
-- Default: flipper and gm
DECK_SETTING_FLIP_VISIBILITY = "flipvisibility";
-- Can the GM see what cards are being face down: yes or no
-- Default: yes
DECK_SETTING_GM_SEE_FACEDOWN_CARDS = "gmseesfacedowncards";
-- Should cards played from a hand be automatically discarded: yes or no
-- Default: no
DECK_SETTING_AUTO_PLAY_FROM_HAND = "autoplayfromhand";
-- Should cards played from a deck be automatically discarded: yes or no
-- Default: yes
DECK_SETTING_AUTO_PLAY_FROM_DECK = "autoplayfromdeck";

local _tSettingOptions = {
	[DECK_SETTING_DEFAULT_DEAL_FACING] = {
		default = "faceup",
		options = {
			{ sTextRes = "deckbox_settings_option_faceup", sValue = "faceup" },
			{ sTextRes = "deckbox_settings_option_facedown", sValue = "facedown" }
		}
	},
	[DECK_SETTING_DEAL_VISIBILITY] = {
		default = "gmandactor",
		options = {
			{ sTextRes = "deckbox_settings_option_recipient", sValue = "actor" },
			{ sTextRes = "deckbox_settings_option_gm", sValue = "gm" },
			{ sTextRes = "deckbox_settings_option_gm_and_recipient", sValue = "gmandactor" },
			{ sTextRes = "deckbox_settings_option_everyone", sValue = "everyone" },
			{ sTextRes = "deckbox_settings_option_none", sValue = "none" }
		}
	},
	[DECK_SETTING_PLAY_VISIBILITY] = {
		default = "everyone",
		options = {
			{ sTextRes = "deckbox_settings_option_player", sValue = "actor" },
			{ sTextRes = "deckbox_settings_option_gm_and_player", sValue = "gmandactor" },
			{ sTextRes = "deckbox_settings_option_everyone", sValue = "everyone" }
		}
	},
	[DECK_SETTING_DISCARD_VISIBILITY] = {
		default = "everyone",
		options = {
			{ sTextRes = "deckbox_settings_option_discarder", sValue = "actor" },
			{ sTextRes = "deckbox_settings_option_gm_and_discarder", sValue = "gmandactor" },
			{ sTextRes = "deckbox_settings_option_everyone", sValue = "everyone" }
		}
	},
	[DECK_SETTING_GIVE_VISIBILITY] = {
		default = "gmandactor",
		options = {
			{ sTextRes = "deckbox_settings_option_giver", sValue = "actor" },
			{ sTextRes = "deckbox_settings_option_gm_and_giver", sValue = "gmandactor" },
			{ sTextRes = "deckbox_settings_option_everyone", sValue = "everyone" }
		}
	},
	[DECK_SETTING_FLIP_VISIBILITY] = {
		default = "gmandactor",
		options = {
			{ sTextRes = "deckbox_settings_option_flipper", sValue = "actor" },
			{ sTextRes = "deckbox_settings_option_gm_and_flipper", sValue = "gmandactor" }
		}
	},
	[DECK_SETTING_GM_SEE_FACEDOWN_CARDS] = {
		default = "yes",
		options = {
			{ sTextRes = "deckbox_setting_option_yes", sValue = "yes" },
			{ sTextRes = "deckbox_setting_option_no", sValue = "no" },
		}
	},
	[DECK_SETTING_AUTO_PLAY_FROM_HAND] = {
		default = "no",
		options = {
			{ sTextRes = "deckbox_setting_option_yes", sValue = "yes" },
			{ sTextRes = "deckbox_setting_option_no", sValue = "no" },
		}
	},
	[DECK_SETTING_AUTO_PLAY_FROM_DECK] = {
		default = "yes",
		options = {
			{ sTextRes = "deckbox_setting_option_yes", sValue = "yes" },
			{ sTextRes = "deckbox_setting_option_no", sValue = "no" },
		}
	}
}

---Gets the deck setting options table for configuring all deck options
---@return table
function getSettingOptions()
	return _tSettingOptions;
end

---Gets a specific deck setting options entry from the options configuration table
---@param sKey string Settings key
---@return table
function getSettingOption(sKey) 
	return _tSettingOptions[sKey];
end

---Gets the settings value for a deck
---@param vDeck databasenode|string
---@param sKey string Settings key
---@return string value
function getDeckSetting(vDeck, sKey)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local settings = DeckedOutUtilities.validateNode(DeckManager.getDeckSettingsNode(vDeck), "settings");
	if not settings then return end

	return DB.getValue(settings, sKey, "");
end

---Gets the settings node for a deck
---@param vDeck databasenode|string
---@return databasenode
function getDeckSettingsNode(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return vDeck.createChild(DeckManager.DECK_SETTINGS_PATH);
end

---Returns true if the GM can see facedown cards for a given deck
---@param vDeck databasenode (or string)
---@return boolean
function canGmSeeFacedownCards(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end
	
	return DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_GM_SEE_FACEDOWN_CARDS) == "yes";
end

---Gets whether the deck should deal cards facedown by default
---@param vDeck databasenode
function dealFacedownByDefault(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local sDefaultFacing = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_DEFAULT_DEAL_FACING)
	return sDefaultFacing == "facedown";
end