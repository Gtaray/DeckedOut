function onDragStart(button, x, y, draginfo)
	CardManager.onDragCard(window.getDatabaseNode(), draginfo);
	return true;
end