local control = nil;
local fOnValueChanged = nil;

function onInit()
	if target and target[1] then
		control = window[target[1]];
		fOnValueChanged = control.onValueChanged;
		control.onValueChanged = onValueChanged;
	end

	update();
end

function onValueChanged()
	if fOnValueChanged then
		fOnValueChanged();
	end
	update();
end

function onDrop(x, y, dragdata)
	if control and dragdata.getTokenData() then
		control.setValue(dragdata.getTokenData());
	end
	return true;
end

function update()
	if control then
		if (control.getPrototype() or "") ~= "" then
			setVisible(false);
			return;
		end
	end

	setVisible(true);
end