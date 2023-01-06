function onDeckDrop(dragdata)
	if dragdata.isType("shortcut") then
		local sClass, sRecord = dragdata.getShortcutData();

		if sClass == "deck" then
			loadDeck(sRecord);
			return true;
		end
	end
end

function loadDeck(sRecord)
	local deckNode = DB.findNode(sRecord);

	if deckNode then
		local decklistNode = DB.createChild(getDatabaseNode(), "decks");
		DB.setPublic(decklistNode, true);

		local newDeckNode = DB.createChild(decklistNode);
		DB.copyNode(deckNode, newDeckNode);
		DB.setPublic(newDeckNode, true);

		local cardsNode = DB.getChild(newDeckNode, "cards");
		local sDeckName = DB.getValue(newDeckNode, "name", "");
		local sDeckId = newDeckNode.getNodeName(); -- DB CHANGE
		for k,v in pairs(DB.getChildren(cardsNode)) do
			DB.setValue(v, "deckname", "string", sDeckName);
			DB.setValue(v, "deckid", "string", sDeckId);
		end

		local settings = DB.createChild(newDeckNode, "settings");
		DB.setPublic(settings, true);

		for key,option in pairs(DeckManager.getSettingOptions()) do
			if option.default then
				DB.setValue(settings, key, "string", option.default)
			end
		end
	end
end