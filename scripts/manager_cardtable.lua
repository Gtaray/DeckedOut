CARD_TABLE_PATH = "deckbox.cardtable";
CARD_TABLE_INIT_NODE = "initialized";

function onInit()
	if not Session.IsHost then
		return;
	end

	if not CardTable.isInitialized() then
		CardTable.initialize();
	end

	DB.addHandler("charsheet.*.cards", "onChildAdded", onCardAddedToHand);
	DB.addHandler("charsheet.*.cards.*", "onDelete", onCardRemovedFromHand);
end

function initialize()
	local cardtable = DB.createNode(CardTable.CARD_TABLE_PATH);
	DB.setPublic(cardtable, true);

	local handnode = DB.createChild(CardTable.getCardTableNode(), "characters");

	for _, charnode in ipairs(DB.getChildList("charsheet")) do
		local charhand = DB.createChild(handnode);
		DB.setValue(charhand, "name", "string", DB.getValue(charnode, "name", ""));
		DB.setValue(charhand, "token", "token", DB.getValue(charnode, "token", ""));
		DB.setValue(charhand, "dbnode", "string", DB.getPath(charnode));

		for _, charcardnode in ipairs(DB.getChildList(charnode, "cards")) do
			local hand = DB.createChild(charhand, "hand");
			local card = DB.createChild(hand);

			CardsManager.deleteFacingNode(card);
			CardsManager.deleteCardOrder(card);

			DB.copyNode(charcardnode, card);
		end
	end

	CardTable.setInitialized(1);
end

------------------------------------------
-- EVENT HANDLERS
------------------------------------------
function onCardAddedToHand(handnode, cardnode)
	
end

function onCardRemovedFromHand(cardnode)
end

------------------------------------------
-- HELPERS
------------------------------------------
---Returns the card table node
---@return databasenode
function getCardTableNode()
	return DB.findNode(CardTable.CARD_TABLE_PATH);
end

---Gets whether the card table has been initialized
---@return boolean
function isInitialized()
	return DB.getValue(
		CardTable.getCardTableNode(), 
		CardTable.CARD_TABLE_INIT_NODE, 0) == 1;
end

---Sets whether the card table has been initialized
---@param nInit number 1 if initialized, 0 if not
function setInitialized(nInit)
	return DB.setValue(
		CardTable.getCardTableNode(), 
		CardTable.CARD_TABLE_INIT_NODE, 
		"number", nInit);
end