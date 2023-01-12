function onDrop(x, y, dragdata)
	if dragdata.isType("shortcut") then
		local sClass, sRecord = dragdata.getShortcutData();

		if sClass == "card" then
			self.onDropCardOnDelete(sRecord);
			return true;
		end
	end
end
function onDropCardOnDelete(vCard)
	vCard = DeckedOutUtilities.validateCard(vCard);
	if not vCard then return end

	local sIdentity = User.getCurrentIdentity();
	-- Either we're the host and the card is in the gm hand
	-- Or we're a client and whose identity matches the card source
	if Session.IsHost then
		CardsManager.discardCard(vCard, DeckedOutUtilities.getFacedownHotkey(), "gm", {});
		return true;
	elseif sIdentity == CardsManager.getCardSource(vCard) then
		CardsManager.discardCard(vCard, DeckedOutUtilities.getFacedownHotkey(), sIdentity, {});
		return true;
	end
end