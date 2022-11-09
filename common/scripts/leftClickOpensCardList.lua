function onClickDown()
	return Session.IsHost;
end
function onClickRelease()
	local target = nil;
	if cardlist and cardlist[1] then
		target = cardlist[1];
	end

	if Session.IsHost then
		local node = nil;
		if target == "deck" then
			node = DeckManager.getCardsNode(window.getDatabaseNode());
		elseif target == "discard" then
			node = DeckManager.getDiscardNode(window.getDatabaseNode());
		end
		if node then
			DesktopManager.openCardList(node);
		end
		return true;
	end
end