---Returns true the facedown hotkey is pressed
---@return boolean bPressed
function getFacedownHotkey()
	return DeckedOutUtilities.getHotkey(OptionsManager.getOption("HOTKEY_FACEDOWN"));
end

---Returns true the play-and-discard hotkey is pressed
---@return boolean bPressed
function getPlayAndDiscardHotkey()
	return DeckedOutUtilities.getHotkey(OptionsManager.getOption("HOTKEY_DISCARD"));
end

---Returns whether an input is pressed based on the input
---@param sOption string Hotkey option
---@return boolean
function getHotkey(sOption)
	if sOption == "shift" then
		return Input.isShiftPressed();
	elseif sOption == "control" then
		return Input.isControlPressed();
	elseif sOption == "alt" then
		return Input.isAltPressed();
	end
end

---Validates that a parameter is not nil. If it is nil, an error and the stack trace is printed in the console
---@param vParam any The parameter to validate
---@param sDisplayName string Display name for the parameter to be validated
---@return boolean
function validateParameter(vParam, sDisplayName)
	if not vParam then
		Debug.console("ERROR: " .. sDisplayName .. " was nil or not found.");
		printstack();
		return false;
	end

	return true;
end

---Validates a character identity
---@param sIdentity string
---@return boolean
function validateIdentity(sIdentity)
	return validateParameter(sIdentity , "sIdentity");
end

---Validates a card databasenode, resolving a string path to a databasenode
---@param vCard databasenode|string
---@return databasenode vCard
function validateCard(vCard)
	if type(vCard) == "string" then
		vCard = DB.findNode(vCard);
	end
	if not DeckedOutUtilities.validateParameter(vCard, "vCard") then
		return;
	end

	return vCard;
end

------Validates a deck databasenode, resolving a string path to a databasenode
---@param vDeck databasenode|string
---@return databasenode vDeck
function validateDeck(vDeck)
	if type(vDeck) == "string" then
		vDeck = DB.findNode(vDeck);
	end
	if not DeckedOutUtilities.validateParameter(vDeck, "vDeck") then
		return;
	end

	return vDeck;
end

---Validates a databasenode, resolving a string path to the databasenode
---@param vNode databasenode|string
---@param sDisplayName string Display name of the node being validated
---@return databasenode
function validateNode(vNode, sDisplayName)
	if type(vNode) == "string" then
		vNode = DB.findNode(vNode);
	end
	if not DeckedOutUtilities.validateParameter(vNode, sDisplayName) then
		return;
	end

	return vNode;
end

---Validates a player's or the GM's hand node
---@param sIdentity string Identity of the player or gm to validate
---@return databasenode
function validateHandNode(sIdentity)
	local handNode = CardManager.getHandNode(sIdentity);
	if handNode == nil then
		Debug.console("ERROR: Could not resolve hand node for user identity" .. sIdentity);
		printstack();
		return;
	end
	return handNode;
end

---Validates whether the current user is the session host
---@return boolean isHost
function validateHost()
	if not Session.IsHost then
		Debug.console("ERROR: This function can only be called by the session host");
		printstack();
		return false;
	end
	return true;
end