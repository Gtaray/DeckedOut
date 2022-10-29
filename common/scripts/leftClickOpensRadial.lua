function isOwner()
	return Session.IsHost or DB.isOwner(window.getDatabaseNode());
end
function onClickDown()
	return self.isOwner();
end
function onClickRelease()
	if self.isOwner() then
		Interface.openRadialMenu();
		return true;
	end
end