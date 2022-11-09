aRecords = {
	["deck"] = {
		bExport = true,
		bID = false,
		aDataMap = { "deck", "reference.decks" },
		sIcon = "sidebar_icon_recordtype_deck"
	}
}

function onInit()
	LibraryData.overrideRecordTypes(aRecords);

	if Session.IsHost then
		DesktopManager.registerSidebarToolButton({
			tooltipres = "sidebar_tooltip_active_deckbox",
			sIcon = "sidebar_icon_deckbox",
			class = "deckbox",
			path = "deckbox",
			sButtonCustomText = "Deckbox"
		});

		-- Create the GM hand node if it doesn't exist
		local node = DB.createNode(CardManager.GM_HAND_PATH);
		node.setPublic(true);
	end

	-- If we're in 2e, then we need to handle the sidebar
	if Session.RulesetName == "2E" then
		
	end
	
	OptionsManager.registerOption2("HOTKEY_FACEDOWN", true, "option_header_deckedout", "option_label_facedown_hotkey", "option_entry_cycler",
			{ labels = "option_val_ctrl|option_val_alt", values = "control|alt", baselabel = "option_val_shift", baseval = "shift", default = "shift" })
	OptionsManager.registerOption2("HOTKEY_DISCARD", true, "option_header_deckedout", "option_label_play_and_discard_hotkey", "option_entry_cycler", 
			{ labels = "option_val_alt|option_val_shift", values = "alt|shift", baselabel = "option_val_ctrl", baseval = "control", default = "control" });
end