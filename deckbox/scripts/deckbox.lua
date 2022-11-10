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
		decklistNode.setPublic(true);

		local newDeckNode = decklistNode.createChild();
		DB.copyNode(deckNode, newDeckNode);
		newDeckNode.setPublic(true);

		local cardsNode = newDeckNode.getChild("cards");
		local sDeckName = DB.getValue(newDeckNode, "name", "");
		local sDeckId = newDeckNode.getNodeName();
		for k,v in pairs(cardsNode.getChildren()) do
			DB.setValue(v, "deckname", "string", sDeckName);
			DB.setValue(v, "deckid", "string", sDeckId);
		end

		local settings = newDeckNode.createChild("settings");
		settings.setPublic(true);

		for key,option in pairs(DeckManager.getSettingOptions()) do
			if option.default then
				DB.setValue(settings, key, "string", option.default)
			end
		end
	end
end