function loadDeck(sRecord)
	local deckNode = DB.findNode(sRecord);
	if deckNode then
		local decklistNode = DB.createChild(getDatabaseNode(), "decks");
		local newDeckNode = decklistNode.createChild();
		DB.copyNode(deckNode, newDeckNode);

		local cardsNode = newDeckNode.getChild("cards");
		local sDeckName = DB.getValue(newDeckNode, "name", "");
		local sDeckId = newDeckNode.getNodeName();
		for k,v in pairs(cardsNode.getChildren()) do
			DB.setValue(v, "deckname", "string", sDeckName);
			DB.setValue(v, "deckid", "string", sDeckId);
		end
	end
end