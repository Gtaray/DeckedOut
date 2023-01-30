function onInit()
	registerMenuItem(Interface.getString("deckbox_menu_play_top_card"), "play_faceup", 1);
	registerMenuItem(Interface.getString("deckbox_menu_play_top_card_facedown"), "play_facedown", 5)

	registerMenuItem(Interface.getString("deckbox_menu_view_deck_cards"), "view_hand", 2);
	registerMenuItem(Interface.getString("deckbox_menu_view_discard_cards"), "discard", 8);

	registerMenuItem(Interface.getString("deckbox_menu_deal_one_to_charaters"), "deal_multiperson", 3)
	registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_characters"), "multideal_multiperson", 4)

	-- registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_characters"), "multideal_multiperson", 1)
	-- registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_characters"), "multideal_multiperson", 2)
	-- registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_characters"), "multideal_multiperson", 3)
	-- registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_characters"), "multideal_multiperson", 4)
	-- registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_characters"), "multideal_multiperson", 5)
	-- registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_characters"), "multideal_multiperson", 6)
	-- registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_characters"), "multideal_multiperson", 7)
	-- registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_characters"), "multideal_multiperson", 8)
end

function onMenuSelection(selection)
	if not Session.IsHost then
		return;
	end
	if selection == 1 then
		playCard(DeckedOutUtilities.getFacedownHotkey());
	elseif selection == 2 then
		DesktopManager.openCardList(DeckManager.getCardsNode(window.getDatabaseNode()));
	elseif selection == 3 then
		dealCards(1);
	elseif selection == 4 then
		DesktopManager.promptCardAmount(dealCards);
	elseif selection == 5 then
		playCard(true);
	elseif selection == 8 then
		DesktopManager.openCardList(DeckManager.getDiscardNode(window.getDatabaseNode()));
	end
end

function onDragStart(button, x, y, draginfo)
	local node = window.getDatabaseNode();
	if Session.IsHost then
		CardsManager.onDragFromDeck(window.getDatabaseNode(), draginfo);
		return true;
	end
end

function onDrop(x, y, draginfo)
	CardsManager.onDropCard(draginfo, window.getDatabaseNode(), DeckManager.DECK_CARDS_PATH);
end

function onDoubleClick(x, y)
	playCard(DeckedOutUtilities.getFacedownHotkey());
end

function playCard(bFacedown)
	local vDeck = window.getDatabaseNode();
	local bDiscard = DeckManager.getDeckSetting(vDeck, DeckManager.DECK_SETTING_AUTO_PLAY_FROM_DECK) == "yes"
	local aCards = DeckManager.getRandomCardsInDeck(vDeck, 1);
	if aCards and aCards[1] then
		CardsManager.playCard(aCards[1], bFacedown, bDiscard or DeckedOutUtilities.getPlayAndDiscardHotkey(), {});
	end
end

function dealCards(nAmount)
	local node = window.getDatabaseNode();
	DeckManager.dealCardsToActiveIdentities(node, nAmount);
end