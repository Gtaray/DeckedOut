function onInit()
	registerMenuItem(Interface.getString("deckbox_menu_close_deck"), "delete", 7);
	registerMenuItem(Interface.getString("list_menu_deleteconfirm"), "delete", 7, 7);
end

function onMenuSelection(selection, subselection)
	if Session.IsHost then
		if selection == 7 and subselection == 7 then
			getDatabaseNode().delete();
		end
	end
end