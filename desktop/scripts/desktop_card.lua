local bPopped = false;
			
function onInit()
	highlight.setEnabled(false);

	local node = getDatabaseNode();
	DB.addHandler(DB.getPath(node, CardManager.CARD_FACING_PATH), "onUpdate", onFacingChanged)

	onFacingChanged();
end

function onClose()
	local node = getDatabaseNode();
	DB.removeHandler(DB.getPath(node, CardManager.CARD_FACING_PATH), "onUpdate", onFacingChanged)
end

function onFacingChanged()
	local bFaceUp = CardManager.isCardFaceUp(getDatabaseNode());
	image.setVisible(bFaceUp);
	image.setEnabled(bFaceUp);
	Debug.chat(cardback.getSize())
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
	if hover and not bPopped then
		highlight.setVisible(true);
		bPopped = true;
	elseif not hover and bPopped then
		highlight.setVisible(false);
		bPopped = false;
	end
end