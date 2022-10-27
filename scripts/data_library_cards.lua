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
	end
end