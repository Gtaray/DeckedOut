local sFilter = "";

function onInit()
	cards.setDatabaseNode(getDatabaseNode());
end

function setTitle(sTitle)
	if (sTitle or "") == "" then
		return;
	end
	title.setValue(string.format(Interface.getString("cardlist_title_formatted"), sTitle));
end

function setSource(sNodeName)
	local sourcenode = getDatabaseNode().getChild(sNodeName);
	if not sourcenode then
		Debug.console("ERROR: cardlist_viewer.setSource(): " .. sNodeName .. " was not found.");
		return
	end

	cards.setDatabaseNode(sourcenode);
end