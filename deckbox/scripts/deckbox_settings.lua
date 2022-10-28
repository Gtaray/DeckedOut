function onInit()
	setTitle();
end

function setTitle()	
	title.setValue(
		string.format(
			Interface.getString("deckbox_settings_title"), 
			DeckManager.getDeckName(getDatabaseNode())));
end