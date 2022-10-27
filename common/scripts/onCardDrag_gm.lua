function onDragStart(button, x, y, draginfo)
	if Session.IsHost then
		CardManager.onDragCard(window.getDatabaseNode(), draginfo);
		return true;
	end
end