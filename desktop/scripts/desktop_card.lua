function onInit()
	registerMenuItem(Interface.getString("card_menu_play_face_up"), "play_faceup", 3);
	registerMenuItem(Interface.getString("card_menu_play_face_down"), "play_facedown", 2);
	registerMenuItem(Interface.getString("card_menu_discard_card"), "discard_card", 7);
end
function onMenuSelection(selection)	
	if selection == 3 then
		-- Player face up
		CardManager.playCard(node(), false, DeckedOutUtilities.shouldPlayAndDiscard(), {})
	elseif selection == 2 then
		-- Play face down
		CardManager.playCard(node(), true, DeckedOutUtilities.shouldPlayAndDiscard(), {})
	elseif selection == 7 then
		-- Discard card
		CardManager.discardCard(node(), DeckedOutUtilities.getFacedownHotkey(), CardManager.getCardSource(node()), {});
	end
end

function node()
	return window.getDatabaseNode();
end

-- CLICKING
function isOwner()
	return DB.isOwner(node()) or Session.IsHost;
end
function onClickDown()
	return self.isOwner();
end
function onClickRelease()
	-- if self.isOwner() then
	-- 	Interface.openRadialMenu();
	-- 	return true;
	-- end
end

function onDoubleClick(x, y)
	-- Show card in chat
	CardManager.playCard(node(), DeckedOutUtilities.getFacedownHotkey(), DeckedOutUtilities.shouldPlayAndDiscard(), {})
end

-- DRAGGING
function onDragStart(button, x, y, draginfo)
	CardManager.onDragCard(node(), draginfo);
	return true;
end