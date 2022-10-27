DECK_CARDS_PATH = "cards";
DECK_DISCARD_PATH = "discard";

------------------------------------------
-- EVENT FUNCTIONS
------------------------------------------
-- Deals the given card to the given identity
function dealCard(vDeck, sIdentity, tEventTrace)
	if not DeckedOutUtilities.validateHost() then return end
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
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
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
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
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
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

------------------------------------------
-- DECK MANAGEMENT
------------------------------------------
-- This function gets a card, without actually removing it from the deck
function drawCard(vDeck)
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local aCards = DeckManager.getRandomCardsInDeck(vDeck, 1);
	return aCards[1];
end

function addCardToDeck(vCard)
	local vCard = DeckedOutUtilities.validateCard(vCard);
	if not vDeck then return end

	local vDeck = DeckedOutUtilities.validateDeck(CardManager.getDeckIdFromCard(vCard));
	if not vDeck then return end

	return CardManager.moveCard(vCard, DeckManager.getCardsNode(vDeck));
end

------------------------------------------
-- DISCARD PILE MANAGEMENT
------------------------------------------
function moveDiscardPileIntoDeck(vDeck)
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
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
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.createChild(vDeck, DeckManager.DECK_CARDS_PATH);
end

function getDiscardNode(vDeck)
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.createChild(vDeck, DeckManager.DECK_DISCARD_PATH);
	
end

function getNumberOfCardsInDeck(vDeck) 
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local cards = DeckManager.getCardsNode(vDeck);
	if not cards then
		return;
	end

	return cards.getChildCount();
end

function getNumberOfCardsInDiscardPile(vDeck) 
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	local discard = DeckManager.getDiscardNode(vDeck);
	if not discard then
		return;
	end

	return discard.getChildCount();
end

function getRandomCardsInDeck(vDeck, nNumberOfCards)
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
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
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.getValue(vDeck, "back", "");
end

function getDeckId(vDeck)
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return vDeck.getNodeName();
end

function getDeckName(vDeck)
	local vDeck = DeckedOutUtilities.validateDeck(vDeck);
	if not vDeck then return end

	return DB.getValue(vDeck, "name", "");
end