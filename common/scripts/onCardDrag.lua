function onDragStart(button, x, y, draginfo)
	local gmDragOnly = window and window.gmdrag and window.gmdrag[1];
	if Session.IsHost == false then
		if gmDragOnly then
			return true;
		end
	end

	CardsManager.onDragCard(window.getDatabaseNode(), draginfo);
	return true;
end