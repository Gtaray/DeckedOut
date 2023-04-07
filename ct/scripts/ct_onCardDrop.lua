function onDrop(x, y, draginfo)
	local handled = CardsManager.onDropCard(draginfo, getDatabaseNode());

	-- For some reason the onDrop call isn't propogating to other objects in the stack, so we call it manually here if present.
	if not handled and super and super.onDrop then
		return super.onDrop(x, y, draginfo);
	end

	return handled;
end