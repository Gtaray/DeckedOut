function onInit()
	if not (target and target[1]) then
		return;
	end

	local node = window.getDatabaseNode();
	local sPath = nil;
	if target[1] == "cards" then
		sPath = DeckManager.DECK_CARDS_PATH;
	elseif target[1] == "discard" then
		sPath = DeckManager.DECK_DISCARD_PATH;
	end

	if sPath ~= nil then
		DB.addHandler(DB.getPath(node, sPath), "onChildAdded", onListUpdated);
		DB.addHandler(DB.getPath(node, sPath), "onChildDeleted", onListUpdated);
	end

	onListUpdated();
end

function onClose()
	if not (target and target[1]) then
		return;
	end

	local node = window.getDatabaseNode();
	local sPath = nil;
	if target[1] == "cards" then
		sPath = DeckManager.DECK_CARDS_PATH;
	elseif target[1] == "discard" then
		sPath = DeckManager.DECK_DISCARD_PATH;
	end

	if sPath ~= nil then
		DB.removeHandler(DB.getPath(node, sPath), "onChildAdded", onListUpdated);
		DB.removeHandler(DB.getPath(node, sPath), "onChildDeleted", onListUpdated);
	end
end

function onListUpdated()
	local nCur = 0;
	if target[1] == "cards" then
		nCur = DeckManager.getNumberOfCardsInDeck(window.getDatabaseNode());
	elseif target[1] == "discard" then
		nCur = DeckManager.getNumberOfCardsInDiscardPile(window.getDatabaseNode());
	end
	setValue(string.format(Interface.getString("deckbox_format_cardcount"), nCur or 0));
end