local sCurrentIdentity = nil;

function onInit()
	User.onIdentityStateChange = onIdentityStateChange;
	self.onSizeChanged = onSizeChanged;

	if Session.IsHost then
		DB.addHandler(CardManager.GM_HAND_PATH, "onChildAdded", onCardAdded);
		DB.addHandler(CardManager.GM_HAND_PATH, "onChildDeleted", onCardDeleted);

		updateHand(CardManager.getHandNode("gm"));
	end

	-- registerMenuItem(Interface.getString("hand_menu_play_random"), "customdice", 4);
	-- registerMenuItem(Interface.getString("hand_menu_discard_random"), "customdice", 6);
	registerMenuItem(Interface.getString("hand_menu_discard_hand"), "discard_hand", 8);
	registerMenuItem(Interface.getString("hand_menu_discard_random"), "discard_random", 8, 7);
	registerMenuItem(Interface.getString("hand_menu_discard_hand_confirm"), "discard_hand", 8, 8);
end

function onClose()
	if Session.IsHost then
		DB.removeHandler(CardManager.GM_HAND_PATH, "onChildAdded", onCardAdded);
		DB.removeHandler(CardManager.GM_HAND_PATH, "onChildDeleted", onCardDeleted);
	else
		clearPlayerCardHandler(User.getCurrentIdentity());
	end
end

function onMenuSelection(selection, subselection)
	if selection == 8 and subselection == 7 then
		local sIdentity = self.getIdentity()
		if sIdentity then
			CardManager.discardRandomCard(sIdentity, DeckedOutUtilities.getFacedownHotkey(), {})
		end
	elseif selection == 8 and subselection == 8 then
		local sIdentity = self.getIdentity()
		if sIdentity then
			-- Pass in empty list for tEventTrace since this is guaranteed to be the first place we have an event chain
			CardManager.discardHand(sIdentity, {});
		end
	end
end

function onIdentityStateChange(sIdentity, sUsername, sStateName, vState)	
	-- if for some reason the GM is here, bail
	if Session.IsHost then
		return;
	end
	
	-- Only grab state change events for when the user changes their
	-- current identity
	if sStateName == "current" then
		if vState then
			addPlayerCardHandler(sIdentity);
			updateHand(CardManager.getHandNode(sIdentity))

			-- If we just activated a character and that character
			-- has cards in their hand, auto-open up the hand window
			-- If there's no cards in hand, close the window
			DesktopManager.setHandVisibility(hand.getWindowCount() > 0);
		else
			clearPlayerCardHandler(sIdentity);
		end
	end
end

function onDrop(x, y, draginfo)
	-- Janky way of handling this, but windows don't have an enabled flag
	-- So instead we have to look to see if the controls are visible or not

	-- Also we don't want players to be able to drag/drop into their hands, because then
	-- They could grab cards from chat (or elsewhere) and drag them into their hand

	-- Maybe players should be able to do this? An option toggle the
	if frame.isVisible() then
		CardManager.onDropCard(draginfo, hand.getDatabaseNode());
	end
end

function onSizeChanged(bIgnore)
	updateHand();
end

function isVisible()
	return frame.isVisible();
end

function updateVisibility(bShow)
	setEnabled(bShow);
	frame.setVisible(bShow);
	hand.setVisible(bShow);
	discard.setVisible(bShow);
end

function getIdentity()
	if Session.IsHost then
		return "gm";
	end

	return sCurrentIdentity;
end

function addPlayerCardHandler(sIdentity)
	if not sCurrentIdentity then
		DB.addHandler(CardManager.getHandPath(sIdentity), "onChildAdded", onCardAdded);
		DB.addHandler(CardManager.getHandPath(sIdentity), "onChildDeleted", onCardDeleted);
		sCurrentIdentity = sIdentity;
	end
end

function clearPlayerCardHandler(sIdentity)
	if sCurrentIdentity then
		DB.removeHandler(CardManager.getHandPath(sIdentity), "onChildAdded", onCardAdded);
		DB.removeHandler(CardManager.getHandPath(sIdentity), "onChildDeleted", onCardDeleted);
		sCurrentIdentity = nil;
	end
end

function onCardAdded(nodeParent, nodeChildAdded)
	DesktopManager.setHandVisibility(true);
	updateHand();
end

function onCardDeleted(nodeParent)
	updateHand();
end

function updateHand(sourceNode)
	if sourceNode then
		hand.setDatabaseNode(sourceNode);
	end

	hand.update();
end