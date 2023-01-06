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
		DB.setPublic(node, true);
	end

	-- If we're in 2e, then we need to handle the sidebar
	if Session.RulesetName == "2E" then
		
	end
	
	OptionsManager.registerOption2("HOTKEY_FACEDOWN", true, "option_header_deckedout", "option_label_facedown_hotkey", "option_entry_cycler",
			{ labels = "option_val_ctrl|option_val_alt", values = "control|alt", baselabel = "option_val_shift", baseval = "shift", default = "shift" })
	OptionsManager.registerOption2("HOTKEY_DISCARD", true, "option_header_deckedout", "option_label_play_and_discard_hotkey", "option_entry_cycler", 
			{ labels = "option_val_alt|option_val_shift", values = "alt|shift", baselabel = "option_val_ctrl", baseval = "control", default = "control" });
	OptionsManager.registerOption2("FLIP_PERMISSION", true, "option_header_deckedout", "option_label_permission_flip", "option_entry_cycler", 
			{ labels = "option_val_yes", values = "yes", baselabel = "option_val_no", baseval = "no", default = "no" });
	OptionsManager.registerOption2("PEEK_PERMISSION", true, "option_header_deckedout", "option_label_permission_peek", "option_entry_cycler", 
			{ labels = "option_val_yes", values = "yes", baselabel = "option_val_no", baseval = "no", default = "no" });
	OptionsManager.registerOption2("SHOW_GM_PEEK_MSG", true, "option_header_deckedout", "option_label_show_gm_peek", "option_entry_cycler", 
			{ labels = "option_val_yes", values = "yes", baselabel = "option_val_no", baseval = "no", default = "no" });
end

function isBetterMenusLoaded()
	return Session.Ruleset == "2E" or MenuManager ~= nil;
end