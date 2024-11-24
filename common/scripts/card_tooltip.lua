function onInit()
	DB.addHandler(DB.getPath(getDatabaseNode(), CardsManager.CARD_FACING_PATH), "onUpdate", updateToken);
	updateToken();
end

function onClose()
	DB.removeHandler(DB.getPath(getDatabaseNode(), CardsManager.CARD_FACING_PATH), "onUpdate", updateToken);
end

function updateToken()
	local node = getDatabaseNode();

	if not node then
		return;
	end

	local decknode = CardsManager.getDeckNodeFromCard(node);
	local sFacingRule = DeckManager.getDeckSetting(decknode, DeckManager.DECK_SETTING_CARD_TOOLTIP_FACING)

	if sFacingRule == "front" then
		image.setPrototype(CardsManager.getCardFront(node));
		return;
	end

	if sFacingRule == "back" then
		image.setPrototype(CardsManager.getCardBack(node));
		return;
	end
	
	-- If we're here, then we want to base the image on the card's facing
	if CardsManager.isCardFaceUp(node) then
		image.setPrototype(CardsManager.getCardFront(node));
	else
		image.setPrototype(CardsManager.getCardBack(node));
	end
end