DECK_CARDS_PATH = "cards";
DECK_DISCARD_PATH = "discard";
DECK_SETTINGS_PATH = "settings";

-- Settings
-- Who can see cards that are being dealt: recipient, recipient and GM, everyone
-- Default: recipient and GM
DECK_SETTING_DEAL_VISIBILITY = "dealvisibility";
-- Who can see cards that are being played: player, player and GM, everyone
-- Default: player and GM
DECK_SETTING_PLAY_VISIBILITY = "playvisibility";
-- Who can see cards that are being discarded: discarder, discarder and GM, everyone
-- Default: discarder and GM
DECK_SETTING_DISCARD_VISIBILITY = "discardvisibility";
-- Who can see cards that are being given: giver and receiver, giver and receiver and gm, everyone
-- Default: giver and receiver and gm
DECK_SETTING_GIVE_VISIBILITY = "discardvisibility";
-- Can the GM see what cards are being face down: yes or no
-- Default: yes
DECK_SETTING_GM_SEE_FACEDOWN_CARDS = "gmseesfacedowncards";
-- Should cards played from a hand be automatically discarded: yes or no
-- Default: no
DECK_SETTING_AUTO_PLAY_FROM_HAND = "autoplayfromhand";
-- Should cards played from a deck be automatically discarded: yes or no
-- Default: yes
DECK_SETTING_AUTO_PLAY_FROM_DECK = "autoplayfromdiscard";

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
-- Deals the given card to the given identity
function dealCard(vDeck, sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end
	if not DeckedOutUtilities.validateIdentity(sIdentity) then return end
	
	local aCards = DeckManager.getRandomCardsInDeck(vDeck, 1);

	if aCards and aCards[1] then
		-- We place a trace event above the addCardToHand call since that call generates more events
		-- We can't call the raise event before addCardToHand, because the card isn't in the hand, yet
		-- and sCardNode would be nil by the time a handler got to it otherwise (as it was moved from the deck)
		-- This makes sure that the trace stack is preserved, while still having the event fire second
		tEventTrace = DeckedOutEvents.addEventTrace(tEventTrace, DeckedOutEvents.DECKEDOUT_EVENT_CARD_DEALT);
		local card = CardManager.addCardToHand(aCards[1], sIdentity, tEventTrace);
		DeckedOutEvents.raiseOnDealCardEvent(card.getNodeName(), sIdentity, tEventTrace);
		return card;
	end
end

-- Deals multiple cards to one person
function dealCards(vDeck, sIdentity, nCardAmount, tEventTrace)
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
	tEventTrace = DeckedOutEvents.raiseOnMultipleCardsDealtEvent(vDeck.getNodeName(), nCardAmount, sIdentity, tEventTrace)

	for i = 1, nCardAmount, 1 do
		DeckManager.dealCard(vDeck, sIdentity, tEventTrace);
	end
end

-- Deals a card to all active identities
function dealCardsToActiveIdentities(vDeck, nCardAmount, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	-- No idea why this would happen, but if it does, don't do anything
	if nCardAmount < 1 then
		return;
	end

	tEventTrace = DeckedOutEvents.raiseOnDealCardsToActiveIdentitiesEvent(vDeck.getNodeName(), nCardAmount, tEventTrace);

	for _,user in ipairs(User.getAllActiveIdentities()) do
		DeckManager.dealCards(vDeck, user, nCardAmount, tEventTrace);
	end
end

function setDeckSetting(vDeck, sKey, sValue, tEventTrace)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	if not DeckedOutUtilities.validateParameter(sValue, "sValue") then
		return
	end

	local settings = DeckManager.getDeckSettingsNode(vDeck);
	settings = DeckedOutUtilities.validateNode(setting, "settingsNode");
	if not settings then return end

	local tEventTrace = DeckedOutEvents.raiseOnDeckSettingChangedEvent(
		vDeck.getNodeName(), 
		sKey, 
		setting.getValue(),
		sValue,
		tEventTrace);

	setting.setValue(sValue);
end


------------------------------------------
-- DECK MANAGEMENT
------------------------------------------
-- This function gets a card, without actually removing it from the deck
function drawCard(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local aCards = DeckManager.getRandomCardsInDeck(vDeck, 1);
	return aCards[1];
end

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
function getCardsNode(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.createChild(vDeck, DeckManager.DECK_CARDS_PATH);
end

function getDiscardNode(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.createChild(vDeck, DeckManager.DECK_DISCARD_PATH);
	
end

function getNumberOfCardsInDeck(vDeck) 
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local cards = DeckManager.getCardsNode(vDeck);
	if not cards then
		return;
	end

	return cards.getChildCount();
end

function getNumberOfCardsInDiscardPile(vDeck) 
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local discard = DeckManager.getDiscardNode(vDeck);
	if not discard then
		return;
	end

	return discard.getChildCount();
end

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

function getDecksCardBack(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.getValue(vDeck, "back", "");
end

function getDeckId(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return vDeck.getNodeName();
end

function getDeckName(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.getValue(vDeck, "name", "");
end

------------------------------------------
-- DECK SETTINGS
------------------------------------------
function getDeckSetting(vDeck, sKey)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local settings = DeckManager.getDeckSettingsNode(vDeck);
	settings = DeckedOutUtilities.validateNode(setting, "settingsNode");
	if not settings then return end

	return setting.getValue();
end

function getDeckSettingsNode(vDeck)
	vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return vDeck.createChild(DeckManager.DECK_SETTINGS_PATH);
end