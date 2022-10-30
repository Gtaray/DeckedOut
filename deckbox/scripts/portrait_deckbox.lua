function onInit()
	if super and super.onInit then
		super.onInit()
	end

	registerMenuItem(Interface.getString("deckbox_menu_deal_one_to_character"), "deal", 2);
	registerMenuItem(Interface.getString("deckbox_menu_deal_multi_to_character"), "deal_multiple", 3);
	registerMenuItem(Interface.getString("deckbox_menu_discard_characters_hand"), "discard_hand", 4);
	registerMenuItem(Interface.getString("deckbox_menu_reshuffle_characters_hand"), "reshuffle_hand", 5);
	registerMenuItem(Interface.getString("deckbox_menu_view_pc_cards_in_hand"), "view_hand", 6);

	update();
end

function onMenuSelection(selection)
	if selection == 2 then
		DeckManager.dealCard(getDeckNode(), getIdentity(), false);
	elseif selection == 3 then
		DesktopManager.promptCardAmount(onCardAmountSelected);
	elseif selection == 4 then
		CardManager.discardCardsInHandFromDeck(getDeckNode(), getIdentity(), {});
	elseif selection == 5 then
		CardManager.putCardsFromDeckInHandBackIntoDeck(getDeckNode(), getIdentity());
	elseif selection == 6 then
		DesktopManager.openCardList(CardManager.getHandNode(getIdentity()));
	end
end

function getDeckNode()
	return window.windowlist.window.getDatabaseNode();
end

function getIdentity()
	return window.getDatabaseNode().getName();
end

function onCardAmountSelected(nAmount)
	DeckManager.dealCards(getDeckNode(), getIdentity(), nAmount);
end

function update()
	local sCharNode = window.getDatabaseNode().getNodeName();
	local sCharNodeName = sCharNode:match("%.([%w-]+)$");
	if sCharNodeName then
		setIcon("portrait_" .. sCharNodeName .. "_charlist", true);
	else
		setIcon();
	end
end

function onDragStart(button, x, y, draginfo)
	local nodeChar = window.getDatabaseNode();
	if DB.isOwner(nodeChar) then
		draginfo.setType("shortcut");
		draginfo.setIcon("portrait_" .. nodeChar.getName() .. "_charlist");
		local sToken = DB.getValue(nodeChar, "token", "");
		if sToken ~= "" then
			draginfo.setTokenData(sToken);
		end
		draginfo.setShortcutData("charsheet", nodeChar.getPath());
		draginfo.setDescription(DB.getValue(nodeChar, "name", ""));
		return true;
	end
end

function onDrop(x, y, draginfo)
	CardManager.onDropCard(draginfo, window.getDatabaseNode());
end