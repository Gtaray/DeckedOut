local winTooltip = nil;
			
function onInit()
	-- highlight.setEnabled(false);

	local node = getDatabaseNode();
	DB.addHandler(DB.getPath(node, CardsManager.CARD_FACING_PATH), "onUpdate", onFacingChanged)

	onFacingChanged();
end

function onClose()
	local node = getDatabaseNode();
	DB.removeHandler(DB.getPath(node, CardsManager.CARD_FACING_PATH), "onUpdate", onFacingChanged)
end

function onFacingChanged(nodeUpdated)
	local bFaceUp = CardsManager.isCardFaceUp(getDatabaseNode());
	image.setVisible(bFaceUp);
	image.setEnabled(bFaceUp);
	cardback.setVisible(not bFaceUp);
	cardback.setEnabled(not bFaceUp);

end

function setCardSize(nWidth, nHeight)
	image.setAnchoredWidth(nWidth);
	image.setAnchoredHeight(nHeight);
	cardback.setAnchoredWidth(nWidth);
	cardback.setAnchoredHeight(nHeight);
end

function onHover(hover)
	if hover and winTooltip == nil then
		local w, h = DeckedOutUtilities.getCardTooltipSize();
		if w == 0 or h == 0 then
			return true;	
		end

		local winWidth, winHeight = getSize();

		-- if for some reason the hand window is so ginormous that the cards are also huge
		-- such that the tooltips would be smaller than the actual cards, don't show them. 
		if w <= winWidth or h <= winHeight then
			return true;
		end

		winTooltip = Interface.openWindow("card_tooltip", getDatabaseNode())
		winTooltip.setSize(w, h); -- Set the size before the position, since position relies on size

		local x, y = self.getPositionOfTooltip();
		winTooltip.setPosition(x, y);
	elseif not hover and winTooltip then
		winTooltip.close();
		winTooltip = nil;
	end
end

function getPositionOfTooltip()
	local x, y = self.getAbovePositionForTooltip();

	-- if the tooltip's y is below 0, then we need to switch to below the card
	if y < 0 then
		x, y = self.getBelowPositionForTooltip();
	end

	-- If the tooltip's x is below 0, nudge to the right
	if x < 0 then
		x = 0;
	end

	-- If the tooltip's x value is beyond the right edge of the hand window, nudge it over
	-- This might not be possible
	local handwindow = Interface.findWindow("desktop_hand", "");
	local hx = handwindow.getPosition();
	local hw = handwindow.getSize();
	local tw = winTooltip.getSize();
	if x + tw > hw + hx then
		x = (hw + hx) - tw;
	end

	return x, y;
end

function getAbovePositionForTooltip()
	local x, y = getPosition();
	local w, h = getSize();
	local w2, h2 = winTooltip.getSize();
	return x + (w/2) - (w2/2), y - h2;
end

function getBelowPositionForTooltip()
	local x, y = getPosition();
	local w, h = getSize();
	local w2, h2 = winTooltip.getSize();
	return x + (w/2) - (w2/2), y + h;
end