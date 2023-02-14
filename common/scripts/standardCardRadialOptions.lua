function onInit()
	if super and super.onInit then
		super.onInit();
	end

	local card = window.getDatabaseNode();
	
	registerMenuItem(Interface.getString("card_menu_play_face_up"), "play_faceup", 1);
	registerMenuItem(Interface.getString("card_menu_play_face_down"), "play_facedown", 5)
	if not CardsManager.isCardInDeck(card) then
		registerMenuItem(Interface.getString("card_menu_reshuffle"), "reshuffle_card", 6)
	end
	if not CardsManager.isCardDiscarded(card) then
		registerMenuItem(Interface.getString("card_menu_discard_card"), "discard_card", 7);
	end

	if canpeek and DeckedOutUtilities.canPeekAtCards() then
		registerMenuItem(Interface.getString("card_menu_peek"), "peek", 2);
	end

	DeckedOutUtilities.addOnCardFlippedHandler(card, onCardFlipped);
	onCardFlipped();
end

function onClose()
	if super and super.onClose then
		super.onClose();
	end
	DeckedOutUtilities.removeOnCardFlippedHandler(card, onCardFlipped);
end

function onCardFlipped()
	if not DeckedOutUtilities.canFlipCards() then
		return
	end

	local vCard = window.getDatabaseNode();
	if not CardsManager.isCardInHand(vCard) then
		return;
	end

	local text;
	if CardsManager.isCardFaceUp(vCard) then	
		text = Interface.getString("card_menu_flip_facedown");
	else
		text = Interface.getString("card_menu_flip_faceup");
	end

	if text then
		registerMenuItem(text, "flip", 3);
	end
end

function onMenuSelection(selection)
	if selection == 1 then
		playCard(DeckedOutUtilities.getFacedownHotkey())
	elseif selection == 2 then
		DesktopManager.peekCard(window.getDatabaseNode());
	elseif selection == 3 then
		CardsManager.flipCardFacing(window.getDatabaseNode(), nil, {}) -- Nil here lets the flip function grab the current identity
	elseif selection == 5 then
		playCard(true);
	elseif selection == 6 then
		CardsManager.putCardBackInDeck(window.getDatabaseNode(), DeckedOutUtilities.getFacedownHotkey(), {});
	elseif selection == 7 then
		-- We pass in nil for sIdentity because discardCard gets the user identity for us
		CardsManager.discardCard(window.getDatabaseNode(), DeckedOutUtilities.getFacedownHotkey(), nil, {});
	end
end

function onDoubleClick(x, y)
	playCard(DeckedOutUtilities.getFacedownHotkey());
end

function playCard(bFacedown)
	local vCard = window.getDatabaseNode();
	local vDeck = CardsManager.getDeckNodeFromCard(vCard);

	local bDiscard = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_AUTO_PLAY_FROM_HAND) == "yes"
	CardsManager.playCard(vCard, bFacedown, bDiscard or DeckedOutUtilities.getPlayAndDiscardHotkey(), {});
end