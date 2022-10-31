function onInit()
	if super and super.onInit then
		super.onInit();
	end
	
	local node = window.getDatabaseNode();
	local parent = node.getParent();
	if parent.getName() ~= CardManager.DECK_DISCARD_PATH then
		registerMenuItem(Interface.getString("card_menu_discard_card"), "delete", 7);
	end
end
function onMenuSelection(selection)
	if super and super.onMenuSelection then
		super.onMenuSelection();
	end

	local sIdentity = User.getCurrentIdentity();
	if Session.IsHost then
		sIdentity = "gm"
	end
	
	if selection == 7 then
		CardManager.discardCard(
			window.getDatabaseNode(), 
			DeckedOutUtilities.getFacedownHotkey(), 
			sIdentity,
			{});
	end
end