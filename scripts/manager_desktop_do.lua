local fConfigureSidebarTheming = nil;
local fOnShortcutDropOnPortrait = nil;

function onInit()
	fConfigureSidebarTheming = DesktopManager.configureSidebarTheming;
	DesktopManager.configureSidebarTheming = configureSidebarTheming;

	fOnShortcutDropOnPortrait = CharacterListManager.onShortcutDrop;
	CharacterListManager.registerDropHandler("shortcut", onShortcutDropOnPortrait);

	DesktopManager.setHandVisibility = setHandVisibility;
	DesktopManager.toggleHandVisibility = toggleHandVisibility;
	DesktopManager.openCardList = openCardList;
	DesktopManager.promptCardAmount = promptCardAmount;
end

function configureSidebarTheming()
	fConfigureSidebarTheming();

	local nDockIconWidth = DesktopManager.getSidebarDockIconWidth();
	local nSidebarVisState = DesktopManager.getSidebarVisibilityState();
	local wShortcuts = DesktopManager.getSidebarWindow();

	if not wShortcuts then
		return;
	end

	wShortcuts.button_hand.setAnchoredHeight(nDockIconWidth);
	-- wShortcuts.button_hand.setAnchoredWidth(nDockIconWidth);

	-- if nSidebarVisState == 2 then
	-- 	wShortcuts.button_hand.setAnchor("left", "button_visibility", "left", "absolute", 0);
	-- 	wShortcuts.button_hand.setAnchor("bottom", "button_visibility", "top", "absolute", 5);
	-- else
	-- 	wShortcuts.button_hand.setAnchor("top", "button_visibility", "top", "absolute", 0);
	-- 	wShortcuts.button_hand.setAnchor("left", "button_visibility", "right", "absolute", 5);
	-- end

	wShortcuts.button_hand_icon.setColor(DesktopManager.getSidebarDockIconColor());
end

-- Kind of janky, but this lets us ensure that the state of the button matches
-- incase we want to toggle the hand visibility outside of pressing the button
function setHandVisibility(bShowHand)
	local window = DesktopManager.getSidebarWindow();
	if window then
		local nState = 0;
		if bShowHand then
			nState = 1;
		end
		window.button_hand.setValue(nState);

		DesktopManager.toggleHandVisibility(bShowHand);
	end
end

function toggleHandVisibility(bShow)
	-- If we're a client that has no active identities, then this function
	-- should do nothing
	if not Session.IsHost and #(User.getActiveIdentities()) == 0 then
		return;
	end

	local window = Interface.findWindow("desktop_hand", "");
	if window then
		window.frame.setVisible(bShow);
		window.frame.setEnabled(bShow);
		window.hand.setVisible(bShow);
		window.hand.setEnabled(bShow);
	end
end

function onShortcutDropOnPortrait(sIdentity, draginfo)
	local sClass, sRecord = draginfo.getShortcutData();
	local nodeSource = draginfo.getDatabaseNode();

	if sClass == "card" then
		CardManager.onDropCard(draginfo, DB.getPath("charsheet", sIdentity));
		return;
	end

	fOnShortcutDropOnPortrait(sIdentity, draginfo);
end

------------------------------------------
-- OTHER WINDOW FUNCTIONS
------------------------------------------
function openCardList(vDeck, sSource)
	local sDeckNodePath = vDeck.getNodeName();
	local sTitle = "";
	if (sSource or "") == "" then
		sSource = "cards";
	end

	local window = Interface.openWindow("cardlist_viewer", vDeck);

	if StringManager.startsWith(sDeckNodePath, "charlist") then
		sTitle = DB.getValue(vDeck.getChild(".."), "name", "");
	else
		sTitle = DB.getValue(vDeck, "name", "");
	end

	if sSource == "discard" then
		sTitle = sTitle .. " (Discard)"
	end

	window.setSource(sSource);
	window.setTitle(sTitle);
end

function promptCardAmount(fCallback)
	local w = Interface.openWindow("dealcards_dialog", "");
	w.setCallback(fCallback);
end