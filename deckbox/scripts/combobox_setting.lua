local bUpdating = false;
local node;

function onInit()
	super.onInit();
	self.onSelect = onValueSelected;

	-- Set the dropdown options
	if parameter and parameter[1] then
		if DeckManager[parameter[1]] then			
			local sKey = DeckManager[parameter[1]];
			local settings = DeckManager.getSettingOption(sKey);

			local settingsnode = DeckManager.getDeckSettingsNode(window.getDatabaseNode());

			node = DB.createChild(settingsnode, sKey, "string");
			DB.addHandler(DB.getPath(node), "onUpdate", onNodeUpdate);

			for k,option in ipairs(settings.options) do
				self.add(option.sValue, Interface.getString(option.sTextRes), false)
			end

			onNodeUpdate();
		end
	end

	self.onSelect = onValueSelected;
end

function onClose()
	if node then
		DB.removeHandler(DB.getPath(node), "onUpdate", onNodeUpdate)
	end
end

function onNodeUpdate()
	setComboValue(DB.getValue(node));
end

function onValueSelected()
	bUpdating = true;
	DB.setValue(DB.getPath(node), "string", self.getSelectedValue()); -- DB CHANGE
	bUpdating = false;
end

function setComboValue(sValue)
	if not bUpdating then
		if (sValue or "") == "" then
			self.setListIndex(1);
			sValue = self.getSelectedValue();
			local node = getDatabaseNode();
			if node then
				DB.setValue(DB.getPath(node), "string", sValue); -- DB CHANGE
			end
		elseif hasValue(sValue) then
			for nIndex,sKnownValue in ipairs(getValues()) do
				if sValue == sKnownValue then
					self.setListIndex(nIndex);
				end
			end
		else
			self.setListValue(string.format(Interface.getString("unknown_parameter_error"), sValue));
		end
	end
end