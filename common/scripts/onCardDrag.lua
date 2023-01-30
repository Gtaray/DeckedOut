function onDragStart(button, x, y, draginfo)
	local gmDragOnly = gmdrag and gmdrag[1];
	if Session.IsHost == false then
		if gmDragOnly then
			return true;
		end
	end

	local cardnode = window.getDatabaseNode();
	CardsManager.onDragCard(cardnode, draginfo);

	if window.onDragStart then
		window.onDragStart(cardnode);
	end

	return true;
end