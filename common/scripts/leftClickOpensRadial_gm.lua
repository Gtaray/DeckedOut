function onClickDown()
	return Session.IsHost;
end
function onClickRelease()
	if Session.IsHost then
		Interface.openRadialMenu();
		return true;
	end
end