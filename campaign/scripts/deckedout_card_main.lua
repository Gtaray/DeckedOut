local bPeek = false;
function onInit()
	local node = getDatabaseNode();
	DB.addHandler(DB.getPath(node, CardsManager.CARD_FACING_PATH), "onUpdate", onFacingChanged)

	update();
end

function onClose()
	local node = getDatabaseNode();
	DB.removeHandler(DB.getPath(node, CardsManager.CARD_FACING_PATH), "onUpdate", onFacingChanged)
end

function onDrop(x, y, draginfo)
	local node = getDatabaseNode();
	local bReadOnly = WindowManager.getReadOnlyState(node);
	if not Session.IsHost or bReadOnly then
		return
	end

	if draginfo.isType("shortcut") then
		local sClass, sRecord = draginfo.getShortcutData();
		CardsManager.setCardRecordLink(getDatabaseNode(), sClass, sRecord);
	else
		local sToken = draginfo.getTokenData()
		if sToken then
			CardsManager.setCardBack(node, sToken)
		end
	end

	update()
end

function onFacingChanged()
	-- If the facing is changed while peeking, we disable peeking
	local bFaceUp = CardsManager.isCardFaceUp(node)
	if bPeek == true and not bFaceUp then
		bPeek = false
	end
	update()
end

function peek()
	bPeek = true;
	update()
end

function update()
	local node = getDatabaseNode();
	local bReadOnly = WindowManager.getReadOnlyState(node);
	local linknode = CardsManager.getCardRecordLinkNode(node);
	local bCardInHand = CardsManager.isCardInHand(node);
	local bCardInStorage = CardStorage.isCardInStorage(node);
	local bHasUniqueBackImage = DB.getValue(node, "back", "") ~= "";
	local bFaceUp = CardsManager.isCardFaceUp(node) or bPeek;

	local bLinkVisible = not bReadOnly or linknode ~= nil
	local bFrontVisible = bFaceUp or not (bCardInHand or bCardInStorage)
	local bBackVisible = not bFaceUp or (not (bCardInHand or bCardInStorage) and bHasUniqueBackImage)

	header_record.setVisible(bLinkVisible)
	recordlink_label.setVisible(bLinkVisible)

	-- Show the front image header only if the other sections are visible
	header_front.setVisible(bLinkVisible or (bFaceUp and bBackVisible))
	image.setVisible(bFrontVisible);
	image.setEnabled(bFrontVisible);

	-- Only show the back header if the the back + some other section is visible
	header_back.setVisible(bBackVisible and (bLinkVisible or bFrontVisible))
	back.setVisible(bBackVisible);
	back.setEnabled(bBackVisible);

end