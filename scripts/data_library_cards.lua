aRecords = {
	-- ["card"] = {
	-- 	bExport = true,
	-- 	bID = false,
	-- 	aDataMap = { "card", "reference.cards" }
	-- },
	["deck"] = {
		bExport = true,
		bID = false,
		aDataMap = { "deck", "reference.decks" }
	}
}

function onInit()
	LibraryData.overrideRecordTypes(aRecords);
	if Session.IsHost then
		DesktopManager.registerSidebarToolButton({
			tooltipres = "sidebar_tooltip_active_deckbox",
			sIcon = "sidebar_icon_deck",
			class = "deckbox",
			path = "deckbox"
		});

		-- Create the GM hand node if it doesn't exist
	local node = DB.createNode(CardManager.GM_HAND_PATH);
	node.setPublic(true);
	end
end