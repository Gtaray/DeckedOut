local bPeek = false;
function onInit()
	local node = getDatabaseNode();
	DB.addHandler(DB.getPath(node, CardsManager.CARD_FACING_PATH), "onUpdate", onFacingChanged)

	onFacingChanged();
	update();
end

function onClose()
	local node = getDatabaseNode();
	DB.removeHandler(DB.getPath(node, CardsManager.CARD_FACING_PATH), "onUpdate", onFacingChanged)
end

function onDrop(x, y, draginfo)
	local bReadOnly = WindowManager.getReadOnlyState(getDatabaseNode());
	if not Session.IsHost or bReadOnly then
		return
	end

	if draginfo.isType("shortcut") then
		local sClass, sRecord = draginfo.getShortcutData();
		CardsManager.setCardRecordLink(getDatabaseNode(), sClass, sRecord);
		return true
	end
end

function onFacingChanged()
	local bFaceUp = CardsManager.isCardFaceUp(getDatabaseNode()) or bPeek;
	image.setVisible(bFaceUp);
	image.setEnabled(bFaceUp);
	back.setVisible(not bFaceUp);
	back.setEnabled(not bFaceUp);
end

function peek()
	bPeek = true;
	onFacingChanged()
end

function update()
	local node = getDatabaseNode();
	local bReadOnly = WindowManager.getReadOnlyState(node);
	local linknode = CardsManager.getCardRecordLinkNode(node);

	local bLabelVisible = not bReadOnly or linknode ~= nil

	Debug.chat('label vis:', bLabelVisible);

	header_record.setVisible(bLabelVisible)
	recordlink_label.setVisible(bLabelVisible)

	-- Show the front image header only if the other sections are visible
	header_front.setVisible(bLabelVisible)
end