function getFacedownHotkey()
	return Input.isShiftPressed();
end

function getPlayAndDiscardHotkey()
	return Input.isControlPressed();
end

function validateParameter(vParam, sDisplayName)
	if not vParam then
		Debug.console("ERROR: " .. sDisplayName .. " was nil or not found.");
		printstack();
		return false;
	end

	return true;
end

function validateIdentity(sIdentity)
	return validateParameter(sIdentity , "sIdentity");
end

function validateCard(vCard)
	if type(vCard) == "string" then
		vCard = DB.findNode(vCard);
	end
	if not DeckedOutUtilities.validateParameter(vCard, "vCard") then
		return;
	end

	return vCard;
end

function validateDeck(vDeck)
	if type(vDeck) == "string" then
		vDeck = DB.findNode(vDeck);
	end
	if not DeckedOutUtilities.validateParameter(vDeck, "vDeck") then
		return;
	end

	return vDeck;
end

function validateNode(vNode, sDisplayName)
	if type(vNode) == "string" then
		vNode = DB.findNode(vNode);
	end
	if not DeckedOutUtilities.validateParameter(vNode, sDisplayName) then
		return;
	end

	return vNode;
end

function validateHandNode(sIdentity)
	local handNode = CardManager.getHandNode(sIdentity);
	if handNode == nil then
		Debug.console("ERROR: Could not resolve hand node for user identity" .. sIdentity);
		printstack();
		return;
	end
	return handNode;
end

function validateHost()
	if not Session.IsHost then
		Debug.console("ERROR: This function can only be called by the session host");
		printstack();
		return false;
	end
	return true;
end