HAND_MARGINS = {
	["top"] = 20,
	["right"] = 7,
	["bottom"] = 20,
	["left"] = 7,
}
CARD_PADDING = 0;
CARD_ASPECT_RATIO = 1.4;

function setSource(sourcenode)
	setDatabaseNode(sourcenode);
end

function addCard(sRecord)
end

function update()
	local nWidth, nHeight = getCardSize();

	setColumnWidth(nWidth + (CARD_PADDING * 2));

	for k,window in ipairs(getWindows()) do
		window.setCardSize(nWidth, nHeight);
	end

	-- Update hand position to center it in the window
	local nHandWidth = (nWidth * getWindowCount());
	local nHandHeight = nHeight;
	local nWindowWidth, nWindowHeight = window.getSize();
	local nPadX = (nWindowWidth - nHandWidth) / 2;
	local nPadY = (nWindowHeight - nHandHeight) / 2;

	setAnchor("left", "", "left", "current", nPadX);
	setAnchor("top", "", "top", "current", nPadY);
	setAnchor("right", "", "right", "current", -nPadX);
	setAnchor("bottom", "", "bottom", "current", -nPadY);
end

function getCardSize()
	local nHandWidth, nHandHeight = window.getSize();

	local nCardCount = getWindowCount();

	local nCardMaxHeight = nHandHeight - HAND_MARGINS["top"] - HAND_MARGINS["bottom"];
	local nCardMaxWidth = (nHandWidth - HAND_MARGINS["left"] - HAND_MARGINS["right"] - (nCardCount * (CARD_PADDING * 2))) / nCardCount

	-- Depending on how  much room we have in what direction
	-- we set the height and width to lock into the aspect ratio
	local nCardWidth, nCardHeight;
	if (nCardMaxHeight < nCardMaxWidth * CARD_ASPECT_RATIO) then
		nCardHeight = nCardMaxHeight;
		nCardWidth = nCardHeight / CARD_ASPECT_RATIO;
	else
		nCardWidth = nCardMaxWidth;
		nCardHeight = nCardWidth * CARD_ASPECT_RATIO;
	end
	
	return nCardWidth, nCardHeight;
end