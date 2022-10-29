local fCallback = nil;

function closeWindow()
	close();
end

function setCallback(callback)
	fCallback = callback;
end

function accept()
	if fCallback then
		fCallback(amount.getValue());
	end
end