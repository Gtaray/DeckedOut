local sCurrentIdentity = nil;

function onInit()
	User.onIdentityStateChange = onIdentityStateChange;
	self.onSizeChanged = onSizeChanged;

	if Session.IsHost then
		DB.addHandler(CardsManager.GM_HAND_PATH, "onChildAdded", onCardAdded);
		DB.addHandler(CardsManager.GM_HAND_PATH, "onChildDeleted", onCardDeleted);

		self.updateHand(CardsManager.getHandNode("gm"));
	end

	registerMenuItem(Interface.getString("hand_menu_discard_hand"), "discard_hand", 8);
	registerMenuItem(Interface.getString("hand_menu_discard_random"), "discard_random", 8, 7);
	registerMenuItem(Interface.getString("hand_menu_discard_hand_confirm"), "discard_hand", 8, 8);
	registerMenuItem(Interface.getString("hand_menu_sort_asc"), "sort_asc", 4)
end

function onClose()
	if Session.IsHost then
		DB.removeHandler(CardsManager.GM_HAND_PATH, "onChildAdded", onCardAdded);
		DB.removeHandler(CardsManager.GM_HAND_PATH, "onChildDeleted", onCardDeleted);
	else
		self.clearPlayerCardHandler(User.getCurrentIdentity());
	end
end

-- This is here to check to see if any of the cards in hand have duplicated order values
-- if they do, we need to build the order, and we do it by decks, then alphabetically.
function onFirstLayout()
	if self.hasDuplicateCardOrders() then
		self.sortCardsInHandAlphabetically();
	end
end

function onMenuSelection(selection, subselection)
	if selection == 4 then
		self.sortCardsInHandAlphabetically();
	elseif selection == 8 and subselection == 7 then
		local sIdentity = self.getIdentity()
		if sIdentity then
			CardsManager.discardRandomCard(sIdentity, DeckedOutUtilities.getFacedownHotkey(), {})
		end
	elseif selection == 8 and subselection == 8 then
		local sIdentity = self.getIdentity()
		if sIdentity then
			-- Pass in empty list for tEventTrace since this is guaranteed to be the first place we have an event chain
			CardsManager.discardHand(sIdentity, {});
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
			self.addPlayerCardHandler(sIdentity);
			self.updateHand(CardsManager.getHandNode(sIdentity))

			-- If we just activated a character and that character
			-- has cards in their hand, auto-open up the hand window
			-- If there's no cards in hand, close the window
			DesktopManager.setHandVisibility(hand.getWindowCount() > 0);
		else
			self.clearPlayerCardHandler(sIdentity);
		end
	end
end

function onDrop(x, y, draginfo)
	-- Janky way of handling this, but windows don't have an enabled flag
	-- So instead we have to look to see if the controls are visible or not
	if self.isVisible() then
		-- We need to save this list before the new card is added to the windowlist
		local orderedCards = self.getOrderedCards();

		local bResult, card = CardsManager.onDropCard(draginfo, hand.getDatabaseNode());

		-- If for some reason the drop wasn't handled, then we don't do any processing
		if bResult == false then
			return bResult;
		end

		-- If this is the first card in the hand, we simply set it's order
		if hand.getWindowCount() == 1 then
			CardsManager.setCardOrder(card, 1);
			return true;
		end

		-- The adjustment window by default starts at the card's old order
		-- If the card is just added, then it will be 0 and thus adjusted below
		local nAdjustmentWindowStart = CardsManager.getCardOrder(card);
		local window = self.getCardAtLocation(x, y);

		
		local nNewOrder = nil;
		if not window then
			-- if window is nil then we simply add the card to the end of the hand
			nNewOrder = hand.getWindowCount();

			-- Only the last card in the hand (the one being added) needs to be adjusted 
			if nAdjustmentWindowStart == 0 then
				nAdjustmentWindowStart = nNewOrder;
			end
		else
			-- If the card was dropped onto another card, we insert the card at the same
			-- card order as the drop target
			nNewOrder = CardsManager.getCardOrder(window.getDatabaseNode());

			if nAdjustmentWindowStart == 0 then
				nAdjustmentWindowStart = hand.getWindowCount() - 1;
			end
		end
		
		-- This shouldn't happen, but just in case it does, set the order to 0 and sort.
		if nNewOrder == nil then
			Debug.console("WARNING: desktop_hand.onDrop(): Failed to apply a sort order to card.");
			CardsManager.setCardOrder(card, 0);
			hand.applySort();
			return true;
		end

		-- Debug.chat(CardsManager.getCardOrder(card) .. ' -> ' .. nNewOrder);
		
		-- Debug.chat('pre-add: ')
		-- Debug.chat(orderedCards);

		-- Increment depends on if we're moving the card higher or lower in the card order
		local nIncrement = -1;
		if nAdjustmentWindowStart < nNewOrder then
			nIncrement = 1;
		end

		-- Debug.chat('nAdjustmentWindowStart', nAdjustmentWindowStart);

		-- I don't use a for loop here because I want to termiante the loop
		-- When the two are equal, and for loops run inclusively
		local index = nAdjustmentWindowStart;
		-- Debug.chat(nAdjustmentWindowStart, nNewOrder, nIncrement)
		while index ~= nNewOrder do
			orderedCards[index] = orderedCards[index + nIncrement]
			index = index + nIncrement;
		end

		orderedCards[nNewOrder] = card;

		-- Debug.chat('post-add:');
		-- Debug.chat(orderedCards);
		for index, cardnode in pairs(orderedCards) do
			CardsManager.setCardOrder(cardnode, index);
			-- Debug.chat(cardnode, CardsManager.getCardOrder(cardnode))
		end

		hand.applySort();
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
		DB.addHandler(CardsManager.getHandPath(sIdentity), "onChildAdded", onCardAdded);
		DB.addHandler(CardsManager.getHandPath(sIdentity), "onChildDeleted", onCardDeleted);
		sCurrentIdentity = sIdentity;
	end
end

function clearPlayerCardHandler(sIdentity)
	if sCurrentIdentity then
		DB.removeHandler(CardsManager.getHandPath(sIdentity), "onChildAdded", onCardAdded);
		DB.removeHandler(CardsManager.getHandPath(sIdentity), "onChildDeleted", onCardDeleted);
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

-------------------------------
-- DRAG / DROP REORDERING
-------------------------------
function sortCardsInHandAlphabetically()
	local cards = {};
	for _, control in pairs(hand.getWindows()) do
		table.insert(cards, control.getDatabaseNode());
	end
	if #cards > 0 then
		CardsManager.sortCardsByDeckAndName(cards);
		hand.applySort();
	end
end

function hasDuplicateCardOrders()
	local dOrders = {};
	for _, control in pairs(hand.getWindows()) do
		local nOrder = control.getOrder()

		if dOrders[nOrder] then
			return true;
		end

		dOrders[nOrder] = true;
	end

	return false;
end

function getOrderedCards()
	local dOrders = {};
	for _, control in pairs(hand.getWindows()) do
		local nOrder = control.getOrder()
		dOrders[nOrder] = control.getDatabaseNode();
	end

	return dOrders;
end

function getCardAtLocation(x, y)
	local hx, hy = hand.getPosition()
	local hw, hh = hand.getSize();

	-- if the drop was outside the bounds of the hand list, then return nil;
	if (x < hx or x > hx + hw) or ( y < hy or y > hy + hh) then
		return nil;
	end

	return hand.getWindowAt(x - hx, y - hy);
end