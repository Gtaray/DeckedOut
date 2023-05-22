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

	if CardsManager.isCardFaceUp(node) then
		image.setPrototype(CardsManager.getCardFront(node));
	else
		image.setPrototype(CardsManager.getCardBack(node));
	end
end