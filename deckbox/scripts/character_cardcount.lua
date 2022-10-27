function onInit()
	DB.addHandler(getDeckIdCardPath(), "onUpdate", onHandUpdated);
	DB.addHandler(getHandPath(), "onChildDeleted", onHandUpdated);

	self.onHandUpdated();
end

function onClose()
	DB.removeHandler(getDeckIdCardPath(), "onUpdate", onHandUpdated);
	DB.addHandler(getHandPath(), "onChildDeleted", onHandUpdated);
end

function getHandPath()
	return CardManager.getHandPath(window.getDatabaseNode().getName());
end

function getDeckIdCardPath()
	return DB.getPath(getHandPath(), "*.deckid");
end

function getDeckNode()
	return window.windowlist.window.getDatabaseNode();
end

function getDeckId()
	return self.getDeckNode().getNodeName();
end

function getIdentity()
	return window.getDatabaseNode().getName();
end

function onHandUpdated()
	local nCur = CardManager.getNumberOfCardsFromDeckInHand(getDeckNode(), getIdentity())

	if nCur == 1 then
		setValue(Interface.getString("deckbox_format_character_cardcount_one"));
	else
		setValue(string.format(Interface.getString("deckbox_format_character_cardcount"), nCur));
	end
end